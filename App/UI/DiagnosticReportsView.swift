import SwiftUI

struct DiagnosticReportsView:View {
    @Environment(\.dismiss) private var dismiss
    @State private var reports:[DiagnosticReport]=[]
    @State private var error:String?
    @State private var removing:DiagnosticReport?
    private let store=DiagnosticReports()
    var body:some View{NavigationStack{ZStack{Ambient();ScrollView{VStack(alignment:.leading,spacing:18){
        Text("تقارير iOS تساعد على تتبّع الانهيارات وتوقف الاستجابة. يحفظها التطبيق على جهازك فقط، ويمكنك مشاركة تقرير تختاره.").font(.system(size:14)).foregroundStyle(Palette.quiet).lineSpacing(5)
        if reports.isEmpty{VStack(spacing:14){Image(systemName:"checkmark.shield").font(.system(size:32,weight:.light));Text("لا توجد تقارير محفوظة").font(.system(size:17,weight:.medium));Text("قد يرسل iOS التقرير بعد الحادث بوقت؛ عدم وجود تقرير لا يؤكد خلو التطبيق من الأعطال.").font(.system(size:12)).foregroundStyle(Palette.quiet).multilineTextAlignment(.center)}.frame(maxWidth:.infinity).padding(24).glass(20).accessibilityIdentifier("diagnostics-empty")}
        ForEach(reports){report in VStack(alignment:.leading,spacing:14){HStack{Image(systemName:"doc.text");Text(report.date,format:.dateTime.day().month().year().hour().minute()).font(.system(size:14));Spacer()};Text(report.crashes>0 ? "\(report.crashes) سجلات انهيار":"تقرير أداء واستجابة").font(.system(size:12)).foregroundStyle(Palette.quiet);HStack{ShareLink(item:report.url){Label("مشاركة التقرير",systemImage:"square.and.arrow.up")};Spacer();Button(role:.destructive){removing=report}label:{Image(systemName:"trash")}.accessibilityLabel("حذف التقرير")}.font(.system(size:14))}.padding(18).glass(18)}
    }.padding(24).frame(maxWidth:720).frame(maxWidth:.infinity)}}.foregroundStyle(Palette.pale).navigationTitle("تقارير الأعطال").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){Button("تم"){dismiss()}.accessibilityIdentifier("diagnostics-close")};ToolbarItem(placement:.topBarTrailing){Button{reload()}label:{Image(systemName:"arrow.clockwise")}.accessibilityLabel("تحديث التقارير")}}.onAppear{reload()}.confirmationDialog("حذف التقرير من هذا الجهاز؟",isPresented:Binding(get:{removing != nil},set:{if !$0{removing=nil}}),titleVisibility:.visible){Button("حذف",role:.destructive){if let report=removing{do{try store.remove(report);reload()}catch{self.error=error.localizedDescription}};removing=nil}}.alert("تعذر قراءة التقرير",isPresented:Binding(get:{error != nil},set:{if !$0{error=nil}})){Button("حسنًا"){error=nil}}message:{Text(error ?? "")}}.cookiesInterface()}
    private func reload(){do{reports=try store.reports()}catch{self.error=error.localizedDescription}}
}
