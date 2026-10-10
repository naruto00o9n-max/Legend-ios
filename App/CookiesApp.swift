import SwiftUI

@main struct CookiesApp:App {
    @State private var generation=UUID()
    init(){Fonts.register();DiagnosticReporter.shared.start();UIView.appearance().tintColor=UIColor.white}
    var body:some Scene{WindowGroup{CookiesSessionRoot().id(generation).onReceive(NotificationCenter.default.publisher(for:AppStorageManager.changed)){_ in generation=UUID()}.onReceive(NotificationCenter.default.publisher(for:AppStorageManager.reset)){_ in generation=UUID()}}}
}
struct CookiesSessionRoot:View {
    @StateObject private var library=LibraryStore()
    @StateObject private var service=ReferenceService()
    @StateObject private var typer=TyperStore()
    @StateObject private var styles=StyleStore()
    @AppStorage("welcome-complete") var entered=false
    @State private var account=false
    init(){if ProcessInfo.processInfo.arguments.contains("-ui-tests"){UserDefaults.standard.removeObject(forKey:"welcome-complete")};Fonts.register();DiagnosticReporter.shared.start();UIView.appearance().tintColor=UIColor.white}
    var body:some View {Group{if entered{NavigationStack{LibraryView()}}else{WelcomeView(begin:{withAnimation(.easeInOut(duration:0.3)){entered=true};account=true},edit:{withAnimation(.easeInOut(duration:0.3)){entered=true}})}}
        .fullScreenCover(isPresented:$account){AccountView()}.onOpenURL{url in if url.isFileURL{Task{await library.importImage(url,parent:nil)}}}
        .environmentObject(library).environmentObject(service).environmentObject(typer).environmentObject(styles).cookiesInterface().dynamicTypeSize(.small ... .xxxLarge)
    }
}
