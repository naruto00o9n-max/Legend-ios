import SwiftUI

@main struct CookiesApp:App {
    @State private var generation=UUID()
    @State private var recoveryError:String?
    init(){if ProcessInfo.processInfo.arguments.contains("-ui-tests"){UserDefaults.standard.removeObject(forKey:"welcome-complete");UserDefaults.standard.removeObject(forKey:"editor-tap-add-text")};do{try AppStorageManager.recoverInterruptedRestore()}catch{_recoveryError=State(initialValue:error.localizedDescription)};try? AppStorageManager.migrateDiagnostics();Fonts.register();DiagnosticReporter.shared.start();UIView.appearance().tintColor=UIColor.white}
    var body:some Scene{WindowGroup{Group{if let recoveryError{VStack(spacing:20){Image(systemName:"externaldrive.badge.exclamationmark").font(.largeTitle);Text("توقفت استعادة البيانات").font(.title2);Text(recoveryError);Text("احتُفظ بنسخة الاسترجاع؛ لم تُفتح المشاريع لحماية ملفاتها.").font(.footnote);Button("إعادة المحاولة"){do{try AppStorageManager.recoverInterruptedRestore();self.recoveryError=nil;generation=UUID()}catch{self.recoveryError=error.localizedDescription}}}.padding(30).cookiesInterface()}else{CookiesSessionRoot().id(generation)}}.onReceive(NotificationCenter.default.publisher(for:AppStorageManager.changed)){_ in generation=UUID()}.onReceive(NotificationCenter.default.publisher(for:AppStorageManager.reset)){_ in generation=UUID()}}}
}
struct CookiesSessionRoot:View {
    @StateObject private var library=LibraryStore()
    @StateObject private var service=ReferenceService()
    @StateObject private var typer=TyperStore()
    @StateObject private var styles=StyleStore()
    @AppStorage("welcome-complete") var entered=false
    @State private var account=false
    var body:some View {Group{if entered{NavigationStack{LibraryView()}}else{WelcomeView(begin:{withAnimation(.easeInOut(duration:0.3)){entered=true};account=true},edit:{withAnimation(.easeInOut(duration:0.3)){entered=true}})}}
        .fullScreenCover(isPresented:$account){AccountView()}.onOpenURL{url in if url.isFileURL{Task{await library.importImage(url,parent:nil)}}}
        .environmentObject(library).environmentObject(service).environmentObject(typer).environmentObject(styles).cookiesInterface().dynamicTypeSize(.small ... .xxxLarge)
    }
}
