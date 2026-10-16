import SwiftUI

/// App-owned dialogs have no iPad popover anchor and remain usable above sheets.
/// Keep the source binding alive until dismissal: item-based actions must still
/// receive their project/layer, and a follow-up dialog must not race this cover.
private struct CookiesDialogModifier<Actions:View,Message:View>:ViewModifier {
    let title:String
    @Binding var isPresented:Bool
    let actions:()->Actions
    let message:()->Message
    @State private var visible=false
    @State private var pendingAction:(()->Void)?
    func body(content:Content)->some View {
        content
            .onAppear{if isPresented{visible=true}}
            .onChange(of:isPresented){_,value in visible=value}
            .fullScreenCover(isPresented:$visible,onDismiss:finish){
                CookiesDialogCard(title:title,actions:actions,message:message,choose:{action in
                    guard pendingAction==nil else{return}
                    pendingAction=action;visible=false
                },cancel:{visible=false})
                .presentationBackground(.clear)
                .interactiveDismissDisabled()
                .cookiesInterface()
            }
    }
    private func finish(){
        let action=pendingAction;pendingAction=nil
        // Execute while the original item binding still identifies the target.
        // The UIKit presentation has finished dismissing, so errors may safely
        // open another app dialog from inside this action.
        action?();isPresented=false
    }
}

private struct CookiesDialogCard<Actions:View,Message:View>:View {
    let title:String
    @ViewBuilder let actions:()->Actions
    @ViewBuilder let message:()->Message
    let choose:(@escaping ()->Void)->Void
    let cancel:()->Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body:some View {
        GeometryReader{geometry in
            ZStack {
                Color.black.opacity(0.65).ignoresSafeArea().accessibilityHidden(true)
                ScrollView {
                    VStack(alignment:.leading,spacing:22){
                        HStack(alignment:.top,spacing:14){
                            Image(systemName:"sparkle").font(.system(size:21,weight:.medium))
                                .foregroundStyle(Palette.gold).frame(width:46,height:46)
                                .background(Palette.gold.opacity(0.1),in:RoundedRectangle(cornerRadius:15))
                            VStack(alignment:.leading,spacing:6){
                                Text("COOKIES EDITOR").font(.system(size:9,weight:.semibold)).tracking(2).foregroundStyle(Palette.quiet)
                                Text(title).font(.title3.weight(.semibold)).fixedSize(horizontal:false,vertical:true)
                                    .accessibilityAddTraits(.isHeader).accessibilityIdentifier("cookies-dialog-title")
                            }
                            Spacer(minLength:0)
                            Button(action:cancel){Image(systemName:"xmark").font(.system(size:13,weight:.semibold)).frame(width:36,height:36).background(.white.opacity(0.06),in:Circle())}
                                .buttonStyle(.plain).accessibilityLabel("إغلاق النافذة").accessibilityIdentifier("cookies-dialog-close")
                        }
                        message().font(.subheadline).foregroundStyle(Palette.secondary)
                            .fixedSize(horizontal:false,vertical:true).lineSpacing(5)
                        Rectangle().fill(LinearGradient(colors:[Palette.gold.opacity(0.4),.white.opacity(0.04)],startPoint:.leading,endPoint:.trailing)).frame(height:1).accessibilityHidden(true)
                        VStack(spacing:12){actions()}
                            .textFieldStyle(CookiesDialogFieldStyle())
                            .buttonStyle(CookiesDialogActionStyle(choose:choose))
                    }
                    .padding(24).foregroundStyle(Palette.pale)
                    .background(reduceTransparency ? AnyShapeStyle(Palette.ink):AnyShapeStyle(.ultraThinMaterial),in:RoundedRectangle(cornerRadius:30,style:.continuous))
                    .glass(30).shadow(color:.black.opacity(0.45),radius:32,y:18)
                    .frame(maxWidth:480).padding(20)
                    .frame(maxWidth:.infinity,minHeight:geometry.size.height)
                }.scrollBounceBehavior(.basedOnSize)
            }
        }
        .accessibilityIdentifier("cookies-dialog")
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape,cancel)
    }
}

private struct CookiesDialogActionStyle:PrimitiveButtonStyle {
    let choose:(@escaping ()->Void)->Void
    func makeBody(configuration:Configuration)->some View {
        Button{choose{configuration.trigger()}}label:{
            HStack(spacing:10){
                if configuration.role == .destructive{Image(systemName:"trash").foregroundStyle(Palette.gold)}
                configuration.label.multilineTextAlignment(.center)
            }.frame(maxWidth:.infinity).padding(.horizontal,16).padding(.vertical,15)
        }
        .buttonStyle(CookiesDialogPressedStyle(cancel:configuration.role == .cancel))
    }
}
private struct CookiesDialogPressedStyle:ButtonStyle {
    let cancel:Bool
    func makeBody(configuration:Configuration)->some View {
        configuration.label.font(.system(size:15,weight:cancel ? .medium:.semibold))
            .foregroundStyle(cancel ? Palette.secondary:Palette.pale)
            .background((configuration.isPressed ? .white.opacity(0.14):cancel ? .white.opacity(0.025):Palette.gold.opacity(0.09)),in:RoundedRectangle(cornerRadius:16))
            .overlay(RoundedRectangle(cornerRadius:16).stroke(cancel ? Palette.line:Palette.gold.opacity(0.4),lineWidth:0.8))
            .contentShape(RoundedRectangle(cornerRadius:16))
    }
}
private struct CookiesDialogFieldStyle:TextFieldStyle {
    func _body(configuration:TextField<Self._Label>)->some View {
        configuration.font(.body).foregroundStyle(.white).tint(Palette.gold).glassField()
    }
}

extension View {
    func cookiesAlert<Actions:View,Message:View>(_ title:String,isPresented:Binding<Bool>,@ViewBuilder actions:@escaping ()->Actions,@ViewBuilder message:@escaping ()->Message)->some View {
        modifier(CookiesDialogModifier(title:title,isPresented:isPresented,actions:actions,message:message))
    }
    func cookiesAlert<Actions:View>(_ title:String,isPresented:Binding<Bool>,@ViewBuilder actions:@escaping ()->Actions)->some View {
        cookiesAlert(title,isPresented:isPresented,actions:actions,message:{EmptyView()})
    }
    func cookiesConfirmationDialog<Actions:View,Message:View>(_ title:String,isPresented:Binding<Bool>,titleVisibility:Visibility = .visible,@ViewBuilder actions:@escaping ()->Actions,@ViewBuilder message:@escaping ()->Message)->some View {
        cookiesAlert(title,isPresented:isPresented,actions:actions,message:message)
    }
    func cookiesConfirmationDialog<Actions:View>(_ title:String,isPresented:Binding<Bool>,titleVisibility:Visibility = .visible,@ViewBuilder actions:@escaping ()->Actions)->some View {
        cookiesAlert(title,isPresented:isPresented,actions:actions)
    }
}

#if DEBUG
/// No network or production data: exercises item lifetime and queued errors in
/// the same confirmation used by the real account screen on both device sizes.
struct CookiesDialogWorkbench:View {
    @State private var selection:VaultProject?
    @State private var removals=0
    @State private var error=false
    private let project=VaultProject(owner_id:"test",project_id:UUID(uuidString:"11111111-1111-1111-1111-111111111111")!,revision_id:UUID(),generation:1,head:VaultHead(title:"فصل الاختبار",bytes:1,sha256:"",chunks:[],width:800,height:15000))
    var body:some View {
        ZStack{Ambient();VStack(spacing:24){
            Text("\(removals)").accessibilityIdentifier("dialog-removal-count")
            Button("حذف نسخة الخادم"){selection=project}.accessibilityIdentifier("dialog-show-delete")
        }}.vaultRemovalConfirmation(project:$selection){target in
            if target.id==project.id{removals+=1};error=true
        }.cookiesAlert("نتيجة الاختبار",isPresented:$error){Button("حسنًا"){} }message:{Text("تلقّى التأكيد المشروع الصحيح بعد إغلاق اللوحة.")}
        .cookiesInterface()
    }
}
#endif
