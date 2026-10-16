import SwiftUI

@main struct CookiesApp:App {
    @State private var generation=UUID()
    @State private var recoveryError:String?
    init(){if ProcessInfo.processInfo.arguments.contains("-ui-tests"){UserDefaults.standard.removeObject(forKey:"welcome-complete");UserDefaults.standard.removeObject(forKey:"editor-tap-add-text");UserDefaults.standard.removeObject(forKey:"editor-grid-data");UserDefaults.standard.removeObject(forKey:WhiteningPreferences.methodKey);UserDefaults.standard.removeObject(forKey:WhiteningPreferences.executionKey)};do{try AppStorageManager.recoverInterruptedRestore();try VaultFiles.recover(root:AppStorageManager.root)}catch{_recoveryError=State(initialValue:error.localizedDescription)};try? AppStorageManager.migrateDiagnostics();Fonts.register();DiagnosticReporter.shared.start();UIView.appearance().tintColor=UIColor.white}
    var body:some Scene{WindowGroup{Group{if let recoveryError{VStack(spacing:20){Image(systemName:"externaldrive.badge.exclamationmark").font(.largeTitle);Text("توقفت استعادة البيانات").font(.title2);Text(recoveryError);Text("احتُفظ بنسخة الاسترجاع؛ لم تُفتح المشاريع لحماية ملفاتها.").font(.footnote);Button("إعادة المحاولة"){do{try AppStorageManager.recoverInterruptedRestore();try VaultFiles.recover(root:AppStorageManager.root);self.recoveryError=nil;generation=UUID()}catch{self.recoveryError=error.localizedDescription}}}.padding(30).cookiesInterface()}else{
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-ui-tests") && ProcessInfo.processInfo.arguments.contains("-dialog-workbench"){CookiesDialogWorkbench()}else{CookiesSessionRoot().id(generation)}
                #else
                CookiesSessionRoot().id(generation)
                #endif
            }}.onReceive(NotificationCenter.default.publisher(for:AppStorageManager.changed)){_ in generation=UUID()}.onReceive(NotificationCenter.default.publisher(for:AppStorageManager.reset)){_ in generation=UUID()}}}
}
struct CookiesSessionRoot:View {
    @StateObject private var library=LibraryStore()
    @StateObject private var service=ReferenceService()
    @StateObject private var typer=TyperStore()
    @StateObject private var styles=StyleStore()
    @AppStorage("welcome-complete") var entered=false
    @State private var account=false
    @Environment(\.scenePhase) private var phase
    var body:some View {Group{if entered{NavigationStack{LibraryView()}}else{WelcomeView(begin:{withAnimation(.easeInOut(duration:0.3)){entered=true};account=NetworkPolicy.enabled},edit:{withAnimation(.easeInOut(duration:0.3)){entered=true}})}}
        .fullScreenCover(isPresented:$account){if NetworkPolicy.enabled{AccountView()}}.onOpenURL{url in if url.isFileURL{Task{await library.importImage(url,parent:nil)}}}
        .onReceive(NotificationCenter.default.publisher(for:UIApplication.didReceiveMemoryWarningNotification)){_ in ImagePipeline.clearMemoryCaches()}.task{library.vault.service=service;ColorLibraryStore.shared.reload()}.onChange(of:phase){_,value in if value != .active{do{try ColorLibraryStore.shared.flushIfNeeded()}catch{ColorLibraryStore.shared.error=error.localizedDescription}}}.onChange(of:service.session?.user.id){_,_ in library.vault.listing=nil}.environmentObject(library).environmentObject(service).environmentObject(typer).environmentObject(styles).cookiesInterface().dynamicTypeSize(.small ... .xxxLarge)
    }
}
