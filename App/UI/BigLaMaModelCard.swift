import SwiftUI

@MainActor struct BigLaMaModelCard:View {
    @ObservedObject private var assets=BigLaMaAssets.shared
    @State private var removal=false
    @State private var failure:String?
    var body:some View{GlassSection("العمل دون إنترنت",icon:"arrow.down.circle",subtitle:"تنزيل اختياري لخدمة الذكاء الاصطناعي"){
        HStack(spacing:12){Image(systemName:assets.ready ? "checkmark.circle":"arrow.down.circle").font(.system(size:25,weight:.light));VStack(alignment:.leading,spacing:5){Text(assets.ready ? "متوفر على الجهاز":"تنزيل اختياري").font(.system(size:14,weight:.semibold));Text("حوالي 208 ميغابايت · لا يتطلب حسابًا").font(.system(size:11)).foregroundStyle(Palette.secondary)};Spacer()}
        Text("نزّل ملفات المعالجة مرة واحدة لتفعيل «دون إنترنت». يمكنك استخدام الخدمة عبر الإنترنت الآن دون هذا التنزيل. راجع النتيجة قبل اعتمادها؛ ترميم التفاصيل المخفية تقديري.").font(.system(size:12)).foregroundStyle(Palette.secondary).lineSpacing(4)
        if assets.installing{VStack(alignment:.leading,spacing:9){HStack{Text(assets.phase);Spacer();Text("\(Int(assets.progress*100))٪").monospacedDigit()}.font(.system(size:12));ProgressView(value:assets.progress).tint(Palette.gold);Button{assets.cancelInstallation()}label:{Label("إيقاف التنزيل",systemImage:"xmark")}.buttonStyle(CapsuleActionStyle())}.accessibilityIdentifier("lama-download-progress")}
        else if assets.ready{Button(role:.destructive){removal=true}label:{Label("إزالة التنزيل لتوفير المساحة",systemImage:"trash")}.buttonStyle(CapsuleActionStyle()).disabled(assets.activeUses>0).accessibilityIdentifier("lama-remove")}
        else{Button{assets.startInstallation()}label:{Label("تنزيل المعالجة دون إنترنت",systemImage:"arrow.down.circle")}.buttonStyle(GoldButtonStyle()).accessibilityIdentifier("lama-download")}
        if let message=failure ?? assets.failure{Label(message,systemImage:"exclamationmark.circle").font(.system(size:12)).foregroundStyle(Palette.secondary).lineSpacing(4)}
    }.disabled(assets.removing).task{assets.refresh()}.alert("إزالة التنزيل؟",isPresented:$removal){Button("إزالة",role:.destructive){Task{do{try await assets.remove()}catch{failure=error.localizedDescription}}};Button("إلغاء",role:.cancel){}}message:{Text("تبقى صورك ومشاريعك كما هي. يمكنك إعادة تنزيل الملفات لاحقًا.")}}
}
