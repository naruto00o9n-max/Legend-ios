import Foundation
import UIKit

enum EditorPreferences {
    static func number(_ key:String,_ fallback:Double,_ bounds:ClosedRange<Double>)->Double {let value=UserDefaults.standard.object(forKey:key) as? Double ?? fallback;return min(bounds.upperBound,max(bounds.lowerBound,value))}
    static var icons:Double{number("editor-icon-scale",1,0.8...1.2)}
    static var toolbar:Double{number("editor-toolbar-scale",1,0.85...1.15)}
    static var panelDensity:Double{number("editor-panel-density",1,0.85...1.15)}
    static var labels:Double{number("editor-label-scale",1,0.85...1.3)}
    static var handleSpeed:Double{number("editor-handle-speed",1,0.25...2)}
    static var typerScale:Double{number("typer-insert-scale",1,0.5...2)}
    static var handles:Double{number("editor-handle-scale",1,0.8...1.5)}
    static var quality:Double{number("editor-preview-quality",1,0.5...2)}
    static var smartPosition:Bool{UserDefaults.standard.object(forKey:"editor-smart-position") as? Bool ?? true}
    static var snap:Bool{UserDefaults.standard.bool(forKey:"editor-snap")}
    static var haptics:Bool{UserDefaults.standard.object(forKey:"editor-haptics") as? Bool ?? true}
    static var motion:Bool{!(UserDefaults.standard.bool(forKey:"editor-reduce-motion") || UIAccessibility.isReduceMotionEnabled)}
    static var cleanRadius:Double{number("editor-clean-radius",3,1...12)}
    static func feedback(){if haptics{UISelectionFeedbackGenerator().selectionChanged()}}
    static func reset(){for key in ["editor-tap-add-text","editor-icon-scale","editor-toolbar-scale","editor-label-scale","editor-handle-scale","editor-preview-quality","editor-snap","editor-haptics","editor-reduce-motion","editor-clean-radius","reader-direction","editor-handle-speed","typer-insert-scale","editor-double-tap","editor-smart-position","text-inline-dock","editor-panel-density"]{UserDefaults.standard.removeObject(forKey:key)}}
}
