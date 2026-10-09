import SwiftUI

@main struct CookiesApp:App {
    @StateObject private var library=LibraryStore()
    @StateObject private var service=ReferenceService()
    @AppStorage("welcome-complete") var entered=false
    @State private var account=false
    init(){if ProcessInfo.processInfo.arguments.contains("-ui-tests"){UserDefaults.standard.removeObject(forKey:"welcome-complete")};Fonts.register();UIView.appearance().tintColor=UIColor(hex:"D4AF37")}
    var body:some Scene {WindowGroup{Group{if entered{NavigationStack{LibraryView()}}else{WelcomeView{withAnimation(.easeInOut(duration:0.3)){entered=true};if NetworkPolicy.enabled{account=true}}}}
        .environmentObject(library).environmentObject(service).environment(\.layoutDirection,.rightToLeft).preferredColorScheme(.dark).tint(Palette.gold).dynamicTypeSize(.small ... .xxxLarge)
        .sheet(isPresented:$account){AccountView()}.onOpenURL{url in if url.isFileURL{Task{await library.importImage(url,parent:nil)}}}
    }}
}
