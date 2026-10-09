import SwiftUI

struct AccountView:View {
    @EnvironmentObject var service:ReferenceService
    @Environment(\.dismiss) var dismiss
    @State private var email="";@State private var password="";@State private var signup=false
    var body:some View {ZStack{Ambient();ScrollView{VStack(alignment:.leading,spacing:18){Brand();Text(signup ? "إنشاء حساب":"مرحبًا بعودتك").font(.system(size:26,weight:.semibold));Text("دخول إلى خدمة YTyper الأصلية").font(.system(size:12)).foregroundStyle(Palette.quiet)
        TextField("البريد الإلكتروني",text:$email).keyboardType(.emailAddress).textContentType(.emailAddress).autocorrectionDisabled().textInputAutocapitalization(.never).padding(14).glass(14).accessibilityIdentifier("account-email")
        SecureField("كلمة المرور",text:$password).textContentType(signup ? .newPassword:.password).padding(14).glass(14).accessibilityIdentifier("account-password")
        if let message=service.message{Text(message).font(.system(size:12)).foregroundStyle(Palette.gold)}
        Button(signup ? "إنشاء الحساب":"تسجيل الدخول"){Task{await service.login(email:email,password:password,signup:signup);password="";if service.session != nil{dismiss()}}}.buttonStyle(GoldButtonStyle(primary:true)).disabled(service.busy).accessibilityIdentifier("account-submit")
        Button("الدخول باستخدام Google"){service.google()}.buttonStyle(GoldButtonStyle())
        Button(signup ? "لدي حساب بالفعل":"إنشاء حساب جديد"){signup.toggle();service.message=nil}.font(.system(size:13));Button("العودة إلى التحرير المحلي"){dismiss()}.font(.system(size:12)).foregroundStyle(Palette.quiet)
    }.padding(24)}}.foregroundStyle(Palette.pale).onChange(of:service.session?.user.id){_,id in if id != nil{dismiss()}}}
}
