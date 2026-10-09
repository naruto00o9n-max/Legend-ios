import SwiftUI

@main struct CookiesApp:App {
    @StateObject private var library=LibraryStore()
    @StateObject private var service=ReferenceService()
    @AppStorage("welcome-complete") var entered=false
    @State private var account=false
    init(){if ProcessInfo.processInfo.arguments.contains("-ui-tests"){UserDefaults.standard.removeObject(forKey:"welcome-complete")};Fonts.register();UIView.appearance().tintColor=UIColor(hex:"D4AF37")}
    var body:some Scene {WindowGroup{Group{if entered{NavigationStack{LibraryView()}}else{WelcomeView(begin:{withAnimation(.easeInOut(duration:0.3)){entered=true};account=true},edit:{withAnimation(.easeInOut(duration:0.3)){entered=true}})}}
        .environmentObject(library).environmentObject(service).environment(\.layoutDirection,.rightToLeft).environment(\.locale,Locale(identifier:"ar")).preferredColorScheme(.dark).tint(Palette.gold).dynamicTypeSize(.small ... .xxxLarge)
        .fullScreenCover(isPresented:$account){AccountView().environmentObject(service)}.onOpenURL{url in if url.isFileURL{Task{await library.importImage(url,parent:nil)}}}
    }}
}
