"""Build an offline Arabic audit viewer; associations are not per-button certification."""
from pathlib import Path
import csv
import html
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/audit'
features = json.loads((OUT / 'feature-parity.json').read_text())
by_id = {r['id']: r for r in features}
inventory = json.loads((OUT / 'original-resource-inventory.json').read_text())

# Manually reviewed destination associations, not claims of visual equivalence.
destinations = {
    'SplashActivity': ('البداية والحساب', 'WelcomeView / AccountView', 'F001 F002 F003 F004 F005', '01-original-launch'),
    'CrashReportActivity': ('تقرير الانهيار', 'تنبيهات أخطاء فقط', 'F147', ''),
    'FolatingWidgetDashboard': ('لوحة التايبر العائم', 'TyperLibraryView / TyperPanel داخل التطبيق', 'F028 F030 F043', ''),
    'FontLibraryActivity': ('مكتبة الخطوط', 'FontLibraryView قائمة واحدة', 'F060 F084 F085 F086', 'screens/23-font-tool'),
    'ArabicFontsActivity': ('الخطوط العربية', 'لا قسم مستقل', 'F084', ''),
    'EnglishFontsActivity': ('الخطوط الإنجليزية', 'لا قسم مستقل', 'F084', ''),
    'ImportedFontsActivity': ('الخطوط المستوردة', 'استيراد في FontLibraryView؛ إدارة ناقصة', 'F084 F085 F086', ''),
    'ImportedStylesActivity': ('الأنماط المستوردة', 'لا مكتبة أنماط محفوظة', 'F081 F082 F086', ''),
    'SettingsActivity': ('الإعدادات', 'SettingsView / TyperSettingsView', 'F141 F142 F143 F144 F145 F146', '06-settings'),
    'StoreActivity': ('المتجر', 'غير منفذ', 'F136', ''),
    'CopyActivity': ('نسخ واستقبال نص التايبر', 'حافظة في ChapterSourceView؛ ليس نفس المسار', 'F021 F033 F043', ''),
    'ProjectsActivity': ('لوحة المشاريع والعمل', 'LibraryView', 'F008 F009 F010 F012 F014', '03-projects-unauthenticated؛10-workspace'),
    'ProjectGalleryActivity': ('معرض صفحات المشروع', 'صور مستقلة ضمن LibraryView', 'F010 F011 F012 F023 F024 F025', ''),
    'WebtoonScraperActivity': ('سحب الفصل', 'غير منفذ', 'F115 F116 F117 F118', ''),
    'EditorActivity': ('المحرر', 'EditorView / StableCanvas / لوحات الأدوات', 'F045 F047 F048 F057 F058 F109 F110', '23-editor-before-text؛24-text-tool؛24-text-handles؛28-editor-header-tools؛29-layers'),
    'ReaderActivity': ('القارئ', 'ReaderView صورة واحدة', 'F113 F114', ''),
    'ImageCropActivity': ('قص الصورة', 'غير منفذ', 'F089', ''),
    'ExportStudioActivity': ('استوديو التصدير', 'ExportSheet صفحة واحدة', 'F119 F120 F121 F122 F123 F124 F125', ''),
    'TagMiniEditorActivity': ('محرر الوسم', 'TagStyleEditor حقول محدودة', 'F034 F035 F036', ''),
    'CommunityActivity': ('المجتمع', 'CommunityView / PostDetailView', 'F126 F127 F128 F129 F130 F131', ''),
    'CreatePostActivity': ('إنشاء منشور', 'غير منفذ', 'F129', ''),
}
compose = {
    'CommunityScreenKt': ('المجتمع', 'CommunityView', 'F126 F127 F128 F129 F130 F131'),
    'DailyRewardsScreenKt': ('المكافآت اليومية', 'غير منفذ', 'F135'),
    'ExportStudioScreenKt': ('استوديو التصدير', 'ExportSheet صفحة واحدة', 'F123 F124'),
    'FontsGridScreenKt': ('شبكة الخطوط', 'قائمة واحدة', 'F084 F085'),
    'InviteScreenKt': ('الدعوات', 'غير منفذ', 'F135'),
    'LeaderboardScreenKt': ('المتصدرون', 'غير منفذ', 'F134'),
    'MergeStudioDialogKt': ('استوديو الدمج', 'غير منفذ', 'F023'),
    'ProjectGalleryScreenKt': ('معرض الصفحات', 'غير منفذ كنموذج فصل', 'F010 F012'),
    'RadialUnlockDialogKt': ('القائمة الدائرية والاستحقاق', 'غير منفذ', 'F049 F136'),
    'ReaderStudioDialogKt': ('استوديو القارئ', 'صورة واحدة', 'F114'),
    'StoreScreenKt': ('المتجر', 'غير منفذ', 'F136'),
    'WatermarkStudioDialogKt': ('استوديو العلامة المائية', 'غير منفذ', 'F026'),
    'WebtoonScraperScreenKt': ('سحب الفصل', 'غير منفذ', 'F115 F116 F117 F118'),
}
screens = []
for activity in inventory['activities']:
    name = activity['name'].split('.')[-1]
    title, ios, ids, capture = destinations[name]
    screens.append(dict(kind='Activity', original=name, title=title, ios=ios,
                        feature_ids=ids, original_capture=capture or 'لم توثق لقطة تشغيل لهذه الوجهة',
                        evidence=activity['source'], visual_status='غير مصدقة'))
for name in inventory['compose_screen_families']:
    title, ios, ids = compose[name]
    screens.append(dict(kind='Compose؛ قد يكرر Activity', original=name, title=title, ios=ios,
                        feature_ids=ids, original_capture='يلزم تحقق الحالة الديناميكية',
                        evidence=name+'.java', visual_status='غير مصدقة'))

layout_groups = {
    'activity_editor': 'F048 F149', 'activity_main': 'F008 F010 F126 F133',
    'activity_image_crop': 'F089', 'activity_reader': 'F113 F114',
    'activity_tag_mini_editor': 'F034 F035', 'dialog_add_text': 'F057 F059',
    'dialog_advanced_gradient': 'F065', 'dialog_interactive_gradient': 'F065',
    'dialog_batch_rename': 'F012', 'dialog_canvas_background': 'F054',
    'dialog_cloud_manager': 'F086 F137 F138', 'dialog_color_picker': 'F064',
    'dialog_delete_confirm': 'F009 F013', 'dialog_discord_link': 'F006',
    'dialog_font_picker': 'F060 F084', 'dialog_glass_input': 'F009 F033',
    'dialog_image_drafts': 'F097', 'dialog_language': 'F145',
    'dialog_layers_glass': 'F110 F111 F112', 'dialog_new_blank_project': 'F014',
    'dialog_page_options': 'F011 F012 F023 F024 F025', 'dialog_preview_layer': 'F111',
    'dialog_process_pages': 'F024 F025', 'dialog_project_options': 'F009 F010 F012',
    'dialog_resize_canvas': 'F025 F090', 'dialog_save': 'F119 F120 F121 F123',
    'dialog_smart_resize': 'F025', 'dialog_style_options': 'F081 F082',
    'dialog_tag_font_picker': 'F034 F036', 'dialog_tag_quick_link': 'F036',
    'dialog_text_format': 'F062', 'dialog_text_line_format': 'F063',
    'dialog_watermark': 'F026', 'dialog_youtube_player': 'F007',
    'item_active_effect': 'F094 F150', 'item_cloud_row': 'F137',
    'item_comment': 'F127 F130', 'item_community_post': 'F126 F128 F130',
    'item_custom_font': 'F084 F085', 'item_draft_chip': 'F097',
    'item_editor_saved_style': 'F081', 'item_font_picker_card': 'F060',
    'item_layer': 'F110 F111', 'item_line_format_row': 'F063',
    'item_page_glass': 'F010 F011 F012', 'item_project_glass': 'F008 F010',
    'item_saved_style': 'F081 F082', 'item_tag_row': 'F034 F035 F036',
    'layout_3d_panel': 'F072', 'layout_background_panel': 'F068',
    'layout_cleaner_pill': 'F107 F108', 'layout_color_panel': 'F064 F065',
    'layout_drawing_brush_panel': 'F100 F101', 'layout_drawing_brush_plus_panel': 'F102',
    'layout_drawing_color_panel': 'F100', 'layout_drawing_eraser_panel': 'F103',
    'layout_drawing_shapes_panel': 'F104', 'layout_drawing_smudge_panel': 'F105',
    'layout_effects_panel': 'F150 F151 F152 F153 F154 F155 F156 F157 F158 F159 F160 F161 F162 F163 F164 F165 F166 F167 F168 F169',
    'layout_eraser_panel': 'F080 F096', 'layout_eyedropper_overlay': 'F056 F083',
    'layout_fade_panel': 'F077', 'layout_floating_widget': 'F043',
    'layout_gradient_map_panel': 'F065', 'layout_image_adjustments_panel': 'F092',
    'layout_image_effects_panel': 'F094', 'layout_image_filters_panel': 'F093',
    'layout_inline_editor': 'F059', 'layout_inpaint_panel': 'F107 F108',
    'layout_inpaint_variations_panel': 'F108', 'layout_magic_brush_panel': 'F095',
    'layout_opacity_panel': 'F076 F091', 'layout_perspective_panel': 'F073 F091 F099',
    'layout_position_panel': 'F070 F088', 'layout_ruler_panel': 'F078',
    'layout_shadow_panel': 'F069', 'layout_snap_settings': 'F052',
    'layout_spacing_panel': 'F071', 'layout_stroke_panel': 'F066 F067',
    'layout_styles_panel': 'F081 F082 F083', 'layout_texture_panel': 'F075',
    'layout_tutorial_card_simple': 'F007', 'layout_typer_panel': 'F028 F029 F030 F031 F032 F033 F034 F035 F036 F037 F038 F039 F040 F041',
    'layout_warp_panel': 'F074',
}
# Refine prominent editor toolbar controls; other IDs retain their layout association.
editor_ids = {
    'btnTyperToggle':'F030', 'btnToolSniper':'F040 F041 F042',
    'btnToolText':'F057', 'btnToolDrawing':'F100 F101 F102 F103 F104 F105',
    'btnToolImage':'F087', 'btnToolShape':'F098', 'btnToolDrafts':'F097',
    'btnToolGrid':'F051', 'btnToolSnap':'F052', 'btnToolLockBg':'F053',
    'btnToolPinBg':'F053', 'btnToolBgInpaint':'F107', 'btnToolReplaceBg':'F090',
    'btnToolCropBg':'F089', 'btnToolPasteImage':'F022', 'btnToolMergeNext':'F023',
    'btnToolSplitPage':'F024', 'btnToolResizeBg':'F025',
}

def write_csv(name, rows):
    with (OUT / name).open('w', encoding='utf-8-sig', newline='') as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)

with (OUT / 'original-buttons-and-inputs.csv').open(encoding='utf-8-sig') as handle:
    controls = list(csv.DictReader(handle))
for row in controls:
    ids = editor_ids.get(row['id']) if row['layout']=='activity_editor' else None
    row['feature_ids'] = ids or layout_groups.get(row['layout'], '')
    row['parent_feature_status'] = '؛ '.join(f'{key}: {by_id[key]["status"]}' for key in row['feature_ids'].split())
    row['association_basis'] = 'معرف الأداة' if ids else 'سياق layout؛ ليس إثبات تطابق كل زر'
    row['individual_verification'] = 'بانتظار مقارنة فعل الزر وحالاته في الأصل وiOS؛ راجع دليل ميزة الأم'
write_csv('control-associations.csv', controls)
write_csv('screen-map.csv', screens)
(OUT / 'screen-map.json').write_text(json.dumps(screens, ensure_ascii=False, indent=2)+'\n')

md = ['# خريطة الواجهات', '',
      '21 وجهة Activity و13 عائلة Compose. قد تكون عائلة Compose داخل Activity أو نافذة؛ لا تُجمع الأعداد لإعلان عدد الشاشات. تضاف النوافذ واللوحات من فهرس layout. وجود الاسم في APK لا يثبت إمكان الوصول إليه بحسابنا.', '',
      '| النوع | الأصل | الوظيفة | المقابل الحالي في iOS | البنود | دليل تشغيل الأصل |',
      '|---|---|---|---|---|---|']
for row in screens:
    md.append('| '+' | '.join(row[key] for key in ['kind','original','title','ios','feature_ids','original_capture'])+' |')
md += ['', '## الأزرار والحقول', '',
       '[633 زرًا محتملًا ومدخلًا مع ربطه بميزة الأم](control-associations.csv). حالة ميزة الأم ليست شهادة لاختبار الزر. يشمل السجل الحجم الافتراضي والنص والتلميح والظهور ومصدر XML والإشارات البرمجية المباشرة. لا تُستبدل به لقطات الحالات الديناميكية.', '',
       '[1090 عنصرًا بمعرف](original-ui-elements.csv)، [فهرس 110 ملفات layout](original-resource-inventory.json)، [70 accessor لإعدادات الأصل](original-preferences.csv). اللوحات التي لا تملك أزرار XML قد تحتوي واجهات Compose أو إجراءات منشأة برمجيًا.']
(OUT / 'screen-map.md').write_text('\n'.join(md)+'\n')

payload = json.dumps(dict(features=features,screens=screens,controls=controls,
                         summary=json.loads((OUT/'audit-summary.json').read_text())),ensure_ascii=False).replace('<','\\u003c')
viewer = '''<!doctype html><html lang="ar" dir="rtl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Cookies · جرد المطابقة</title>
<style>:root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#090909;color:#f2f2f2;font:16px system-ui;line-height:1.7;overflow-wrap:anywhere}main{max-width:1400px;margin:auto;padding:28px}h1{font-size:clamp(24px,4vw,40px);margin:0}h2{font-size:20px}p{max-width:1000px;color:#bdbdbd}a{color:#e0be6a}button,input,select{font:inherit;background:#191919;color:white;border:1px solid #444;border-radius:10px;padding:10px}button{cursor:pointer}button[aria-pressed=true]{border-color:#d4af37;background:#30291a}.bar{display:flex;gap:10px;flex-wrap:wrap;margin:20px 0}.bar input{flex:1;min-width:180px}.stats{display:flex;gap:12px;flex-wrap:wrap}.stat{background:#171717;border:1px solid #333;border-radius:14px;padding:12px 20px}.stat b{display:block;color:#e0be6a;font-size:26px}article{background:#141414;border:1px solid #303030;border-radius:14px;padding:18px;margin:12px 0}article h2{margin:0}small{color:#b9b9b9}details{margin-top:12px}summary{cursor:pointer;color:#e0be6a}dl{display:grid;grid-template-columns:150px 1fr;gap:8px}dt{color:#aaa}dd{margin:0;overflow-wrap:anywhere}.code{direction:ltr;unicode-bidi:embed;font-family:monospace}table{width:100%;border-collapse:collapse;font-size:14px}td,th{padding:10px;text-align:right;border-bottom:1px solid #333;vertical-align:top;overflow-wrap:anywhere}.table{overflow:auto}th{background:#191919}.note{border-right:3px solid #d4af37;padding:12px;background:#171717}@media(max-width:600px){main{padding:16px}dl{grid-template-columns:1fr}dd{padding-bottom:8px}table{min-width:800px}}</style>
<main><small>YTyper 4.5 → iOS 25d6f9f · 9 أكتوبر 2026</small><h1>جرد Cookies Editor وخطة الإكمال</h1>
<p>الهوية تتغير، وتبقى أدوات الأصل وسير عمله مرجع المطابقة. يمكنك البحث وتصفية الميزات وقراءة الفجوة والدليل. «موجود» يعني وجود الوظيفة الأساسية، ولا يعني اعتماد التصميم أو كل حالات الأداء.</p>
<div class="note">تجربتك أكدت البريد وكلمة المرور والتعليق والتايبر والقنص. Google غير مثبت. الجرد البرمجي لا يثبت تشغيل كل واجهة؛ المجتمع والملف والمتجر في الأصل يحتاجون أدلة حساب عادي. أعداد البنود ليست نسبة اكتمال.</div>
<p><a href="implementation-plan.md">خطة المراحل وبوابات القبول</a> · <a href="comparison-ar.md">التقرير الكامل</a> · <a href="feature-parity.csv">CSV الميزات</a> · <a href="control-associations.csv">CSV الأزرار والحقول</a> · <a href="original-preferences.csv">إعدادات الأصل</a> · <a href="https://github.com/naruto00o9n-max/Legend-ios/actions/runs/37951150601">أدلة المحاكيات وIPA الحالي</a></p>
<div class="stats" id="stats"></div><nav class="bar" aria-label="نوع الجرد"><button data-tab="features" aria-pressed="true">182 بند مقارنة</button><button data-tab="screens" aria-pressed="false">خريطة الواجهات</button><button data-tab="controls" aria-pressed="false">633 زرًا ومدخلًا</button></nav>
<div class="bar"><input id="search" aria-label="ابحث" placeholder="ابحث عن ميزة أو زر أو ملف…"><select id="status" aria-label="الحالة"><option value="">كل الحالات</option></select><select id="phase" aria-label="المرحلة"><option value="">كل المراحل</option></select><select id="group" aria-label="المجموعة"><option value="">كل المجموعات</option></select></div><p id="count" aria-live="polite"></p><section id="results"></section>
<p>اختبارات iPhone: 27 نجاحًا. iPad: 26 نجاحًا وفشل انتظار جاهزية cache واحد؛ يحتاج تصحيحًا وإعادة تحقق. فحص المصدر 800×15000 على iPhone: 48 مليون بايت دون تغيير. لا يوجد قياس موثق للأداء الفيزيائي. لا تظهر حسابات الاختبار أو مفاتيحها في هذا التقرير.</p></main>
<script type="application/json" id="data">PAYLOAD</script><script>
const d=JSON.parse(document.getElementById('data').textContent),el=id=>document.getElementById(id);let tab='features';
function esc(x){return String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
for(const [s,n]of Object.entries(d.summary.functional_status_counts)){el('stats').insertAdjacentHTML('beforeend',`<div class="stat"><b>${n}</b>${esc(s)}</div>`);el('status').insertAdjacentHTML('beforeend',`<option>${esc(s)}</option>`)}
for(let i=0;i<7;i++)el('phase').insertAdjacentHTML('beforeend',`<option value="${i}">المرحلة ${i}</option>`);
for(const g of new Set(d.features.map(r=>r.group)))el('group').insertAdjacentHTML('beforeend',`<option>${esc(g)}</option>`);
function render(){const q=el('search').value.trim().toLowerCase(),s=el('status').value,p=el('phase').value,g=el('group').value;let rows=d[tab].filter(r=>{const parents=tab==='features'?[r]:d.features.filter(f=>(r.feature_ids||'').split(' ').includes(f.id));return (!q||JSON.stringify(r).toLowerCase().includes(q))&&parents.some(f=>(!s||f.status===s)&&(!p||f.phase===p)&&(!g||f.group===g))});
el('count').textContent=`${rows.length} نتيجة من ${d[tab].length} · حالة زر مرتبطة بميزة الأم ليست اختبارًا منفردًا.`;
if(tab==='features'){el('results').innerHTML=rows.map(r=>`<article><small>${esc(r.id)} · ${esc(r.group)} · المرحلة ${esc(r.phase)} · ${esc(r.status)}</small><h2>${esc(r.feature)}</h2><p>${esc(r.gap)}</p><details><summary>الدليل ومتطلبات الإكمال</summary><dl>${[['دليل الأصل',r.original_evidence],['دليل الآيفون',r.ios_evidence],['الاعتماد',r.dependency],['اختبار القبول',r.acceptance],['المطابقة البصرية',r.visual_parity]].map(([a,b])=>`<dt>${esc(a)}</dt><dd>${esc(b)}</dd>`).join('')}</dl></details></article>`).join('');return}
const cols=tab==='screens'?[['title','الوجهة'],['original','الأصل'],['kind','النوع'],['ios','الآيفون الحالي'],['feature_ids','البنود'],['original_capture','لقطة الأصل']]:[['layout','اللوحة'],['id','معرف الزر'],['text','النص'],['type','نوع العنصر'],['width','العرض'],['height','الارتفاع'],['feature_ids','ميزة الأم'],['parent_feature_status','حالة الأم'],['individual_verification','تحقق الزر']];el('results').innerHTML=`<div class="table"><table><thead><tr>${cols.map(c=>`<th>${c[1]}</th>`).join('')}</tr></thead><tbody>${rows.map(r=>`<tr>${cols.map(c=>`<td>${esc(r[c[0]])}</td>`).join('')}</tr>`).join('')}</tbody></table></div>`}
document.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>{tab=b.dataset.tab;document.querySelectorAll('[data-tab]').forEach(x=>x.setAttribute('aria-pressed',String(x===b)));render()});for(const id of ['search','status','phase','group'])el(id).addEventListener(id==='search'?'input':'change',render);render();</script></html>'''
(OUT / 'index.html').write_text(viewer.replace('PAYLOAD',payload))
print(f'Built {len(screens)} destination rows, {len(controls)} associated controls, {len(features)} feature rows')
