import SwiftUI

struct AccountView: View {
    @EnvironmentObject var service: ReferenceService
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var signup = false
    @FocusState private var focus: String?
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Ambient()
                ScrollView {
                    VStack(spacing: 0) {
                        HStack { Brand(); Spacer(); IconButton(icon: "xmark", title: "متابعة التحرير") { dismiss() }.accessibilityIdentifier("account-skip") }
                            .padding(.horizontal, 28).padding(.top, 20)
                        Spacer(minLength: max(36, geometry.size.height * 0.1))
                        VStack(alignment: .leading, spacing: 22) {
                            Image("CookiesLogo").resizable().scaledToFit().frame(width: 64, height: 64).clipShape(Circle())
                            VStack(alignment: .leading, spacing: 10) {
                                Text(signup ? "أنشئ حسابك" : "مرحبًا بعودتك").font(.system(size: 32, weight: .semibold))
                                Text(signup ? "حساب واحد لأعمالك ومجتمعك." : "سجّل الدخول للوصول إلى حسابك والمجتمع.").font(.system(size: 14)).foregroundStyle(Palette.quiet)
                            }
                            if signup { TextField("الاسم", text: $name).textContentType(.name).padding(16).glass(14).accessibilityIdentifier("account-name") }
                            VStack(spacing: 12) {
                                TextField("البريد الإلكتروني", text: $email).keyboardType(.emailAddress).textContentType(.emailAddress).autocorrectionDisabled().textInputAutocapitalization(.never).focused($focus, equals: "email").environment(\.layoutDirection, .leftToRight).padding(16).glass(14).accessibilityIdentifier("account-email")
                                SecureField("كلمة المرور", text: $password).textContentType(signup ? .newPassword : .password).focused($focus, equals: "password").submitLabel(.go).padding(16).glass(14).accessibilityIdentifier("account-password")
                            }
                            if let message = service.message {
                                HStack(alignment: .top, spacing: 10) { Image(systemName: "info.circle"); Text(message).font(.system(size: 12)).lineSpacing(5).textSelection(.enabled) }.padding(14).glass(12).accessibilityIdentifier("account-message")
                            }
                            Button { submit() } label: { HStack { if service.busy { ProgressView().tint(Palette.ink) }; Text(signup ? "إنشاء الحساب" : "تسجيل الدخول") } }.buttonStyle(GoldButtonStyle(primary: true)).disabled(service.busy).accessibilityIdentifier("account-submit")
                            HStack { Rectangle().fill(.white.opacity(0.1)).frame(height: 1); Text("أو").font(.system(size: 12)).foregroundStyle(Palette.quiet); Rectangle().fill(.white.opacity(0.1)).frame(height: 1) }
                            Button { focus = nil; service.google() } label: { Label("الدخول باستخدام Google", systemImage: "globe") }.buttonStyle(GoldButtonStyle()).disabled(service.busy).accessibilityIdentifier("account-google")
                            Button(signup ? "لدي حساب بالفعل" : "إنشاء حساب جديد") { withAnimation(.easeInOut(duration: 0.2)) { signup.toggle(); service.message = nil } }.font(.system(size: 14)).frame(maxWidth: .infinity)
                            Button("متابعة التحرير") { dismiss() }.font(.system(size: 13)).foregroundStyle(Palette.quiet).frame(maxWidth: .infinity)
                        }.frame(maxWidth: 420).padding(.horizontal, 28)
                        Spacer(minLength: 44)
                    }.frame(minHeight: geometry.size.height, alignment: .top)
                }.scrollDismissesKeyboard(.interactively)
            }
        }.foregroundStyle(Palette.pale).onChange(of: service.session?.user.id) { _, id in if id != nil { dismiss() } }
    }
    private func submit() {
        focus = nil
        Task { await service.login(email: email, password: password, signup: signup, name: name); if service.session != nil { password = ""; dismiss() } }
    }
}
