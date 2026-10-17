import SwiftUI

/// An over-full-screen UIKit presentation keeps the editor mounted and avoids
/// iPad popover anchors. In particular it must not call the underlying editor's
/// onDisappear cleanup when a naming/confirmation card opens.
private struct CookiesDialogModifier<Actions:View,Message:View>:ViewModifier {
    let title:String
    @Binding var isPresented:Bool
    let actions:()->Actions
    let message:()->Message
    func body(content:Content)->some View {
        content.background {
            CookiesDialogPresenter(isPresented:$isPresented){choose,cancel in
                AnyView(CookiesDialogCard(title:title,actions:actions,message:message,choose:choose,cancel:cancel).cookiesInterface())
            }.frame(width:0,height:0).accessibilityHidden(true)
        }
    }
}

private struct CookiesDialogPresenter:UIViewControllerRepresentable {
    @Binding var isPresented:Bool
    let makeContent:(_ choose:@escaping (@escaping ()->Void)->Void,_ cancel:@escaping ()->Void)->AnyView
    func makeCoordinator()->Coordinator{Coordinator()}
    func makeUIViewController(context:Context)->UIViewController {
        let controller=UIViewController();controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled=false;context.coordinator.anchor=controller
        return controller
    }
    func updateUIViewController(_ controller:UIViewController,context:Context){
        context.coordinator.binding=$isPresented;context.coordinator.makeContent=makeContent
        context.coordinator.reconcile()
    }
    static func dismantleUIViewController(_ controller:UIViewController,coordinator:Coordinator){
        coordinator.active=false;coordinator.host?.dismiss(animated:false);coordinator.host=nil
    }
    @MainActor final class Coordinator {
        weak var anchor:UIViewController?
        var binding:Binding<Bool> = .constant(false)
        var makeContent:((_ choose:@escaping (@escaping ()->Void)->Void,_ cancel:@escaping ()->Void)->AnyView)?
        var host:UIHostingController<AnyView>?
        var active=true
        private var scheduled=false
        private var finishing=false
        func reconcile(){
            guard active,!finishing else{return}
            guard binding.wrappedValue else{if host != nil{finish(nil)};return}
            if let host{host.rootView=content();return}
            guard !scheduled else{return};scheduled=true
            DispatchQueue.main.async{[weak self] in self?.scheduled=false;self?.presentWhenReady()}
        }
        private func content()->AnyView {
            makeContent?({[weak self] action in self?.finish(action)},{[weak self] in self?.finish(nil)}) ?? AnyView(EmptyView())
        }
        private func presentWhenReady(){
            guard active,binding.wrappedValue,host==nil,!finishing else{return}
            guard let root=anchor?.view.window?.rootViewController else{retry();return}
            var top=root
            while let next=top.presentedViewController{top=next}
            // Two views may observe the same error. The first card owns the
            // interaction; its dismissal clears that error before another card
            // can present. Also wait for a Files/Photos dismissal transition.
            guard !(top is UIHostingController<AnyView> && top.restorationIdentifier=="cookies-dialog-host"),!top.isBeingDismissed,!top.isBeingPresented,top.transitionCoordinator==nil else{retry();return}
            let controller=UIHostingController(rootView:content())
            controller.restorationIdentifier="cookies-dialog-host"
            controller.modalPresentationStyle = .overFullScreen
            controller.modalTransitionStyle = .crossDissolve
            controller.isModalInPresentation=true
            controller.view.backgroundColor = .clear
            controller.view.accessibilityViewIsModal=true
            host=controller
            top.present(controller,animated:!UIAccessibility.isReduceMotionEnabled){UIAccessibility.post(notification:.screenChanged,argument:nil)}
        }
        private func retry(){
            guard !scheduled else{return};scheduled=true
            DispatchQueue.main.asyncAfter(deadline:.now()+0.15){[weak self] in self?.scheduled=false;self?.presentWhenReady()}
        }
        private func finish(_ action:(()->Void)?){
            guard !finishing else{return};finishing=true
            guard let controller=host else{finishing=false;binding.wrappedValue=false;return}
            controller.dismiss(animated:!UIAccessibility.isReduceMotionEnabled){[self] in
                host=nil
                // Keep item-based bindings alive until the action receives its
                // exact target. Follow-up errors can now present without racing
                // the dismiss transition, and Cancel never triggers an action.
                action?();binding.wrappedValue=false;finishing=false
                UIAccessibility.post(notification:.screenChanged,argument:nil)
            }
        }
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
                    VStack(alignment:.leading,spacing:16){
                        HStack(alignment:.center,spacing:12){
                            Image("CookiesLogo").resizable().scaledToFit().frame(width:34,height:34).clipShape(Circle()).accessibilityHidden(true)
                            VStack(alignment:.leading,spacing:6){
                                Text("COOKIES EDITOR").font(.system(size:9,weight:.semibold)).tracking(2).foregroundStyle(Palette.quiet)
                                Text(title).font(.system(size:18,weight:.semibold)).fixedSize(horizontal:false,vertical:true)
                                    .accessibilityAddTraits(.isHeader).accessibilityIdentifier("cookies-dialog-title")
                            }
                            Spacer(minLength:0)
                            Button(action:cancel){Image(systemName:"xmark").font(.system(size:13,weight:.semibold)).frame(width:40,height:40).background(.white.opacity(0.06),in:Circle())}
                                .buttonStyle(.plain).accessibilityLabel("إغلاق النافذة").accessibilityIdentifier("cookies-dialog-close")
                        }
                        message().font(.system(size:14)).foregroundStyle(Palette.secondary)
                            .fixedSize(horizontal:false,vertical:true).lineSpacing(4)
                        Rectangle().fill(LinearGradient(colors:[Palette.gold.opacity(0.4),.white.opacity(0.04)],startPoint:.leading,endPoint:.trailing)).frame(height:1).accessibilityHidden(true)
                        VStack(spacing:10){actions()}
                            .textFieldStyle(CookiesDialogFieldStyle())
                            .buttonStyle(CookiesDialogActionStyle(choose:choose))
                    }
                    .padding(20).foregroundStyle(Palette.pale)
                    .background(reduceTransparency ? AnyShapeStyle(Palette.ink):AnyShapeStyle(.ultraThinMaterial),in:RoundedRectangle(cornerRadius:24,style:.continuous))
                    .glass(24).shadow(color:.black.opacity(0.45),radius:32,y:18)
                    .frame(maxWidth:440).padding(18)
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
        // Rendering another Button here nests primitive styles, duplicating
        // destructive glyphs/padding. Keep one label and one activation path.
        CookiesDialogActionLabel(label:configuration.label,role:configuration.role){choose{configuration.trigger()}}
    }
}
private struct CookiesDialogActionLabel<Label:View>:View {
    let label:Label
    let role:ButtonRole?
    let activate:()->Void
    @Environment(\.isEnabled) private var enabled
    @GestureState private var pressed=false
    private var cancel:Bool{role == .cancel}
    var body:some View {
        HStack(spacing:10){
            label.multilineTextAlignment(.center)
        }
        .font(.system(size:15,weight:cancel ? .medium:.semibold))
        .foregroundStyle(cancel ? Palette.secondary:Palette.pale)
        .frame(maxWidth:.infinity).padding(.horizontal,16).padding(.vertical,15)
        .background(pressed ? .white.opacity(0.14):cancel ? .white.opacity(0.025):Palette.gold.opacity(0.09),in:RoundedRectangle(cornerRadius:16))
        .overlay(RoundedRectangle(cornerRadius:16).stroke(cancel ? Palette.line:Palette.gold.opacity(0.4),lineWidth:0.8))
        .opacity(enabled ? 1:0.4).contentShape(RoundedRectangle(cornerRadius:16))
        .onTapGesture{if enabled{activate()}}
        .simultaneousGesture(DragGesture(minimumDistance:0).updating($pressed){_,state,_ in state=true})
        .accessibilityElement(children:.combine).accessibilityAddTraits(.isButton)
        .accessibilityAction{if enabled{activate()}}
        .focusable(enabled)
        .onKeyPress(keys:[.return,.space]){_ in if enabled{activate();return .handled};return .ignored}
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
    @State private var disappearances=0
    @State private var error=false
    private let project=VaultProject(owner_id:"test",project_id:UUID(uuidString:"11111111-1111-1111-1111-111111111111")!,revision_id:UUID(),generation:1,head:VaultHead(title:"فصل الاختبار",bytes:1,sha256:"",chunks:[],width:800,height:15000))
    var body:some View {
        ZStack{Ambient();VStack(spacing:24){
            Text("\(removals)").accessibilityIdentifier("dialog-removal-count")
            Text("\(disappearances)").accessibilityIdentifier("dialog-underlay-disappearances")
            Button("حذف نسخة الخادم"){selection=project}.accessibilityIdentifier("dialog-show-delete")
        }}.onDisappear{disappearances+=1}.vaultRemovalConfirmation(project:$selection){target in
            if target.id==project.id{removals+=1};error=true
        }.cookiesAlert("نتيجة الاختبار",isPresented:$error){Button("حسنًا"){} }message:{Text("تلقّى التأكيد المشروع الصحيح بعد إغلاق اللوحة.")}
        .cookiesInterface()
    }
}
#endif
