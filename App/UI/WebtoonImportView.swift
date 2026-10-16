import SwiftUI
import WebKit

struct WebtoonImage:Identifiable,Equatable {var url:URL;var width:Int;var height:Int;var id:String{url.absoluteString}}
@MainActor final class WebtoonBrowser:NSObject,ObservableObject,WKNavigationDelegate {
    @Published var address=""
    @Published var title="سحب الفصل"
    @Published var images:[WebtoonImage]=[]
    @Published var loading=false
    @Published var error:String?
    let web=WKWebView(frame:.zero)
    override init(){super.init();web.navigationDelegate=self;web.isOpaque=false;web.backgroundColor = .black;web.scrollView.backgroundColor = .black}
    func open(){var value=address.trimmingCharacters(in:.whitespacesAndNewlines);if !value.contains("://"){value="https://"+value};guard let url=URL(string:value),["http","https"].contains(url.scheme?.lowercased() ?? ""),url.host != nil else{error="اكتب رابط فصل صالح";return};images=[];loading=true;web.load(URLRequest(url:url))}
    func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!){address=webView.url?.absoluteString ?? address;title=webView.title ?? "الفصل";loading=false;Task{await extract()}}
    func webView(_ webView:WKWebView,didFail navigation:WKNavigation!,withError error:Error){loading=false;self.error=error.localizedDescription}
    func webView(_ webView:WKWebView,didFailProvisionalNavigation navigation:WKNavigation!,withError error:Error){loading=false;self.error=error.localizedDescription}
    func extract() async {
        let script="""
        (()=>{const out=[];const seen=new Set();const add=(src,w,h)=>{if(!src)return;try{const url=new URL(src,location.href);if(!/^https?:$/.test(url.protocol)||seen.has(url.href))return;seen.add(url.href);out.push({url:url.href,width:w||0,height:h||0})}catch{}};
        for(const img of document.images){const lazy=img.getAttribute('data-src')||img.getAttribute('data-original')||img.getAttribute('data-lazy-src');add(lazy||img.currentSrc||img.src,img.naturalWidth||img.width,img.naturalHeight||img.height);const srcset=img.getAttribute('data-srcset')||img.getAttribute('srcset');if(srcset){const choices=srcset.split(',');add(choices[choices.length-1].trim().split(/\\s+/)[0],img.naturalWidth,img.naturalHeight)}}
        for(const el of document.querySelectorAll('div,section,figure')){const bg=getComputedStyle(el).backgroundImage;const m=bg.match(/^url\\(["']?(.*?)["']?\\)$/);if(m)add(m[1],el.clientWidth,el.clientHeight)}return out})()
        """
        do{let value=try await web.evaluateJavaScript(script) as? [[String:Any]] ?? [];images=value.compactMap{row in guard let string=row["url"] as? String,let url=URL(string:string) else{return nil};return WebtoonImage(url:url,width:row["width"] as? Int ?? 0,height:row["height"] as? Int ?? 0)}}catch{self.error=error.localizedDescription}
    }
    func scrollAndExtract() async throws {
        var settled=0,lastHeight=0.0
        for _ in 0..<300 {try Task.checkCancellation();let state=try await web.evaluateJavaScript("window.scrollBy(0,Math.max(500,innerHeight*.8));[document.documentElement.scrollHeight,document.documentElement.scrollHeight-(scrollY+innerHeight)]") as? [Double] ?? [];try await Task.sleep(nanoseconds:300_000_000);await extract();let height=state.first ?? 0,remaining=state.last ?? 1;if remaining<2 && height==lastHeight{settled+=1}else{settled=0};lastHeight=height;if settled>=6{break}}
    }
    func download(_ image:WebtoonImage) async throws->URL {
        var request=URLRequest(url:image.url);request.timeoutInterval=45
        if let url=web.url{request.setValue(url.absoluteString,forHTTPHeaderField:"Referer")}
        if let agent=try? await web.evaluateJavaScript("navigator.userAgent") as? String{request.setValue(agent,forHTTPHeaderField:"User-Agent")}
        let cookies:[HTTPCookie]=await withCheckedContinuation{continuation in web.configuration.websiteDataStore.httpCookieStore.getAllCookies{continuation.resume(returning:$0)}}
        let host=image.url.host?.lowercased() ?? ""
        let applicable=cookies.filter{cookie in let domain=cookie.domain.lowercased().trimmingCharacters(in:CharacterSet(charactersIn:"."));return (host==domain || host.hasSuffix("."+domain)) && image.url.path.hasPrefix(cookie.path) && (!cookie.isSecure || image.url.scheme=="https")}
        for (header,value) in HTTPCookie.requestHeaderFields(with:applicable){request.setValue(value,forHTTPHeaderField:header)}
        let (file,response)=try await URLSession.shared.download(for:request)
        guard let http=response as? HTTPURLResponse,(200..<300).contains(http.statusCode),response.mimeType?.hasPrefix("image/")==true else{throw ImageFailure.message("لم يُرجع الموقع صورة قابلة للتنزيل")}
        let size=(try FileManager.default.attributesOfItem(atPath:file.path)[.size] as? NSNumber)?.int64Value ?? 0
        guard size>0,size<=64*1024*1024 else{throw ImageFailure.message("الصورة فارغة أو أكبر من 64 ميغابايت")}
        let suggested=(response.suggestedFilename ?? image.url.lastPathComponent) as NSString
        let suffix=URL(fileURLWithPath:suggested.lastPathComponent).pathExtension
        let name=UUID().uuidString+"."+(suffix.isEmpty ? "jpg":suffix)
        let owned=FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try FileManager.default.copyItem(at:file,to:owned);return owned
    }
}
struct WebtoonWebView:UIViewRepresentable {
    @ObservedObject var browser:WebtoonBrowser
    func makeUIView(context:Context)->WKWebView{browser.web}
    func updateUIView(_ view:WKWebView,context:Context){}
}
struct WebtoonImportView:View {
    @EnvironmentObject var library:LibraryStore
    @Environment(\.dismiss) var dismiss
    @StateObject private var browser=WebtoonBrowser()
    let chapter:UUID
    @State private var choosing=false
    @State private var selected=Set<String>()
    @State private var ordered:[WebtoonImage]=[]
    @State private var busy=false
    @State private var progress=0
    @State private var failed:[WebtoonImage]=[]
    @State private var task:Task<Void,Never>?
    @State private var failure:String?
    @State private var pendingFiles:[String:URL]=[:]
    @State private var batch:[WebtoonImage]=[]
    var body:some View{NavigationStack{ZStack{Ambient();VStack(spacing:12){
        VStack(alignment:.leading,spacing:12){HStack(spacing:10){SurfaceSymbol(icon:"globe",size:36);VStack(alignment:.leading,spacing:3){Text(choosing ? "صور الفصل":"متصفح الفصل").font(.system(size:16,weight:.semibold));Text(choosing ? "رتّب الصور واختر ما تريد استيراده":"افتح الرابط، ثم اجمع صور الصفحة").font(.system(size:10)).foregroundStyle(Palette.quiet)};Spacer()};HStack(spacing:10){Image(systemName:"link").foregroundStyle(Palette.quiet);TextField("رابط الفصل",text:$browser.address).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled().environment(\.layoutDirection,.leftToRight).font(.system(size:12)).onSubmit{browser.open()};Button{browser.open()}label:{Image(systemName:"arrow.up.left").frame(width:32,height:32).background(Palette.gold.opacity(0.12),in:RoundedRectangle(cornerRadius:10))}.accessibilityLabel("فتح الرابط")}.glassField()}.padding(.horizontal,16)
        if browser.loading{ProgressView().tint(Palette.gold)}
        if choosing{
            HStack{QuietBadge(text:"\(selected.count) / \(ordered.count) صور",icon:"photo.stack");Spacer();Button("الكل"){selected=Set(ordered.map(\.id))}.buttonStyle(CapsuleActionStyle());Button("إلغاء"){selected=[]}.buttonStyle(CapsuleActionStyle())}.padding(.horizontal,16)
            List{ForEach(ordered){image in HStack(spacing:12){Button{if selected.contains(image.id){selected.remove(image.id)}else{selected.insert(image.id)}}label:{Image(systemName:selected.contains(image.id) ? "checkmark.circle.fill":"circle").font(.system(size:19)).foregroundStyle(selected.contains(image.id) ? Palette.gold:.white).frame(width:32,height:44)};AsyncImage(url:image.url){phase in if let picture=phase.image{picture.resizable().scaledToFit()}else{Image(systemName:"photo").foregroundStyle(Palette.quiet)}}.frame(width:58,height:76).background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:10));VStack(alignment:.leading,spacing:7){Text(image.url.lastPathComponent).font(.system(size:12,weight:.medium)).lineLimit(2);Text("\(image.width) × \(image.height)").font(.system(size:10,design:.monospaced)).foregroundStyle(Palette.quiet)};Spacer(minLength:0);Button(role:.destructive){selected.remove(image.id);ordered.removeAll{$0.id==image.id}}label:{Image(systemName:"trash").font(.system(size:13)).foregroundStyle(Palette.quiet).frame(width:30,height:44)}}.padding(10).glass(17).listRowSeparator(.hidden).listRowBackground(Color.clear)}.onMove{ordered.move(fromOffsets:$0,toOffset:$1)}}.environment(\.editMode,.constant(.active)).listStyle(.plain).buttonStyle(.borderless).scrollContentBackground(.hidden)
        }else{WebtoonWebView(browser:browser).clipShape(RoundedRectangle(cornerRadius:20)).overlay(RoundedRectangle(cornerRadius:20).stroke(Palette.line,lineWidth:1)).padding(.horizontal,12)}
        if busy{HStack(spacing:12){ProgressView();Text("\(progress) صور جاهزة").font(.system(size:12));Spacer();Button("إلغاء"){task?.cancel()}.buttonStyle(CapsuleActionStyle())}.padding(.horizontal,16)}
        if !failed.isEmpty{VStack(spacing:8){Button("إعادة محاولة \(failed.count) صور"){download(failed,retrying:true)}.buttonStyle(GoldButtonStyle());Button("استيراد الناجح فقط"){task=Task{await commitDownloads()}}.buttonStyle(GoldButtonStyle())}.disabled(busy).padding(.horizontal,16)}
        VStack(spacing:10){ScrollView(.horizontal,showsIndicators:false){HStack(spacing:10){Button{browser.web.goBack()}label:{Image(systemName:"chevron.right")}.accessibilityLabel("الصفحة السابقة");Button{browser.web.goForward()}label:{Image(systemName:"chevron.left")}.accessibilityLabel("الصفحة التالية");Button{task=Task{busy=true;defer{busy=false};do{try await browser.scrollAndExtract()}catch is CancellationError{}catch{failure=error.localizedDescription}}}label:{Label("تمرير تلقائي",systemImage:"arrow.down.to.line")}.disabled(busy);Button{chooseImages()}label:{Label(choosing ? "المتصفح":"عرض الصور",systemImage:choosing ? "globe":"photo.stack")}}.buttonStyle(CapsuleActionStyle()).padding(.horizontal,16)};if choosing{Button{download(ordered.filter{selected.contains($0.id)})}label:{Label("استيراد \(selected.count) صور بالترتيب",systemImage:"arrow.down.doc")}.buttonStyle(GoldButtonStyle(primary:true)).disabled(selected.isEmpty || busy || !pendingFiles.isEmpty).padding(.horizontal,16)}}.padding(.vertical,12).glass(0)
    }.padding(.top,12)}.foregroundStyle(Palette.pale).navigationTitle("سحب الفصل").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){Button("إغلاق"){task?.cancel();discardDownloads();dismiss()}}}.onDisappear{task?.cancel();discardDownloads()}.cookiesAlert("تعذر سحب الفصل",isPresented:Binding(get:{failure != nil || browser.error != nil},set:{if !$0{failure=nil;browser.error=nil}})){Button("حسنًا"){failure=nil;browser.error=nil}}message:{Text(failure ?? browser.error ?? "")}}}
    private func chooseImages(){if !choosing{Task{await browser.extract();ordered=browser.images;selected=Set(ordered.filter{$0.width>=300 && $0.height>=250}.map(\.id));if selected.isEmpty{selected=Set(ordered.map(\.id))};choosing=true}}else{choosing=false}}

    func discardDownloads(){for file in pendingFiles.values{try? FileManager.default.removeItem(at:file)};pendingFiles=[:];failed=[];batch=[]}
    func commitDownloads() async {
        guard !busy else{return};busy=true;defer{busy=false}
        let files=batch.compactMap{pendingFiles[$0.id]}
        guard !files.isEmpty else{return}
        do{try await library.importPages(files,chapter:chapter);discardDownloads();dismiss()}catch{failure=error.localizedDescription}
    }
    func download(_ images:[WebtoonImage],retrying:Bool=false){
        if !retrying{discardDownloads();batch=images}
        task=Task{busy=true;progress=pendingFiles.count;failed=[]
            do{for image in images{try Task.checkCancellation();do{let file=try await browser.download(image);if Task.isCancelled{try? FileManager.default.removeItem(at:file);throw CancellationError()};pendingFiles[image.id]=file;progress+=1}catch is CancellationError{throw CancellationError()}catch{failed.append(image)}}
                busy=false
                if failed.isEmpty{await commitDownloads()}else{failure="تعذر تنزيل \(failed.count) صورة. احتُفظ بالصور الناجحة مؤقتًا؛ أعد المحاولة للحفاظ على ترتيب الفصل، أو اختر استيراد الناجح فقط."}
            }catch is CancellationError{busy=false;discardDownloads()}catch{busy=false;failure=error.localizedDescription}
        }
    }
}
