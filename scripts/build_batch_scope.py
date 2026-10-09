"""Maintain the first 70-item batch ledger, preserving recorded execution evidence."""
from pathlib import Path
import csv
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/audit'
features = json.loads((OUT / 'feature-parity.json').read_text())
lookup = {row['id']: row for row in features}
groups = [
    ('الثبات والجلسة والتحقق', '005 047 147 148',
     'جلسة البريد تحفظ وتجدد وتخرج بصورة صحيحة؛ الرسم والتحريك لحظيان؛ انتظار جاهزية cache بدل sleep؛ اجتياز iPad وiPhone وفحص الصورة الطويلة بايتًا، مع معالجة فشل الشبكة والتخزين.'),
    ('الفصول والاستيراد والسحب والتصدير', '010 011 012 014 016 017 019 023 024 025 090 114 115 116 117 118 122 123 124 125',
     'فصل بصفحات مرتبة وغلاف وتحديد متعدد ولوحة فارغة؛ استيراد صيغ الصور وPDF والأرشيفات الموثقة؛ دمج وتقسيم وتغيير مقاس دون فقد الطبقات؛ سحب صور فصل مع المعاينة والاختيار والتقدم والإلغاء وإعادة الفشل؛ قارئ متعدد الصفحات وتصدير محدد/كامل وPhotos. التوافق مع مشروع الأصل يثبت بعينة فعلية ولا يستبدل بصيغة Cookies.'),
    ('التايبر والقنص وسير عمل المحرر', '034 035 036 037 038 039 041 044 048 052 059 141 143',
     'مجموعات وسوم وخطوط سريعة؛ تحرير وترتيب فقاعات ومقاس لوحة؛ قواعد // والعناوين؛ مسودات قابلة للاسترجاع؛ توزيع النص على أهداف القنص بالترتيب؛ وضع الأدوات يستبدل الشريط؛ Snap؛ محرر Inline وإعدادات تغير السلوك وتستمر. لا فقد لسجل الفقاعات الرمادية بعد إعادة الفتح.'),
    ('النص والأنماط والخطوط', '062 063 064 065 067 068 069 070 071 073 075 076 077 078 079 080 081 082 083 084 085',
     'تنسيق مدى وسطر وكشيدة؛ تدرج داخل الحروف فقط؛ حدود إضافية وظل وخلفية مستقلة؛ موضع وتباعد وخامة وشفافية وتلاشٍ؛ منظور وشبكة بمقابض داخل اللوحة؛ مسطرة وتحويل PNG وأقنعة مسح/استرجاع؛ إنشاء وإدارة واستيراد وتصدير الأنماط والوسوم وقطارة النمط؛ أقسام ومجموعات الخطوط وحذف المخصص وتصديره. تطابق المعاينة والتصدير والحفظ، ومقارنة العربي والتشكيل مع الأصل.'),
    ('الرسم والتنظيف', '101 102 103 104 105 106 108',
     'SOFT/MARKER وخامة مخصصة وBrush Plus وشفافية؛ محو مباشر؛ مستطيل ودائرة وخط وتعبئة وSmudge؛ معاينة وتنويعات تنظيف واعتماد وإلغاء. النتيجة تظهر أثناء اللمس وتبقى نفسها بعد التراجع والحفظ والتصدير وقرب حدود البلاطات.'),
    ('الطبقات', '111 112',
     'فلاتر أنواع الطبقات ومعاينة مكبرة وتحديد متعدد ودمج وتسطيح وتجميع؛ حفظ الترتيب والشفافية والمزج والنتيجة المركبة، مع تراجع واستعادة بعد فتح المشروع.'),
    ('إعدادات الواجهة والقارئ والانتقالات', '142 144 146',
     'مقاسات أدوات وخطوط ومقابض وكثافة آمنة؛ اتجاه قارئ وجودة معاينة ودقة لوحة ومنظف ذكي موصلة فعليًا؛ انتقالات واستجابة ضغط وReduce Motion. لا عناصر خارج شاشة iPad في الاتجاهين ولا تغيير صامت لدقة الأصل عند تغيير المعاينة.'),
]
selected = ['F' + number for _, numbers, _ in groups for number in numbers.split()]
assert len(selected) == len(set(selected)) == 70
assert all(key in lookup for key in selected)
path = OUT / 'batch-01-ledger.json'
previous = json.loads(path.read_text()) if path.exists() else None
old = {row['id']: row for row in previous['tasks']} if previous else {}
if previous is None:
    eligible = [r for r in features if r['status'] in ('جزئي', 'ناقص')]
    assert len(eligible) == 139
    assert all(lookup[key]['status'] in ('جزئي', 'ناقص') for key in selected)
else:
    eligible_ids = previous['eligible_baseline_ids']
    eligible = [lookup[key] for key in eligible_ids]
tasks = []
for order, (group, numbers, gate) in enumerate(groups, start=1):
    for number in numbers.split():
        key = 'F' + number
        feature = lookup[key]
        prior = old.get(key, {})
        tasks.append(dict(
            id=key, group=group, workstream=order, feature=feature['feature'],
            baseline_status=prior.get('baseline_status', feature['status']),
            execution_status=prior.get('execution_status', 'لم يبدأ'),
            original_evidence=feature['original_evidence'],
            ios_baseline=feature['ios_evidence'],
            remaining=prior.get('remaining', feature['gap']),
            acceptance=gate,
            evidence=prior.get('evidence', ''),
            commit=prior.get('commit', ''), run=prior.get('run', ''),
            visual_status=prior.get('visual_status', 'لم يتحقق'),
            performance_status=prior.get('performance_status', 'لم يتحقق'),
        ))
deferred = [r for r in eligible if r['id'] not in selected]
assert len(deferred) == 69
ledger = dict(
    batch='01', baseline_audit_commit='d87d7a2f12954d273fbef47ab1c9d6310bf9344f',
    baseline_ios_commit='25d6f9f50832f0f1c22e2f49ca878ad520ed126f',
    eligible_baseline_ids=[r['id'] for r in eligible], eligible_count=139,
    selected_count=70, deferred_count=69,
    percentage_of_item_count=round(100 * 70 / 139, 2),
    not_percentage_of_effort_or_app_parity=True,
    tasks=tasks,
)
path.write_text(json.dumps(ledger, ensure_ascii=False, indent=2)+'\n')
def write_csv(name, rows):
    with (OUT / name).open('w', encoding='utf-8-sig', newline='') as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]), lineterminator='\n')
        writer.writeheader()
        writer.writerows(rows)
write_csv('batch-01-tasks.csv', tasks)
write_csv('batch-02-deferred.csv', [dict(id=r['id'], group=r['group'], feature=r['feature'],
    baseline_status=old.get(r['id'],{}).get('baseline_status',r['status']),
    gap=r['gap'], reason='خارج نصف الجرد المختار؛ محفوظ للدفعة اللاحقة') for r in deferred])
md = ['# قائمة الدفعة الأولى: 70 بندًا من الجزئي والناقص', '',
      'خط الأساس: **50 جزئيًا + 89 ناقصًا = 139 بندًا**. المختار 70 بندًا (50.36% من عدد البنود، بالتقريب إلى الأعلى)، والمتبقي 69. ليس هذا 50% من حجم البرمجة أو من مطابقة التطبيق الكامل. البنود الخارجية الثمانية المصنفة «اعتماد خادم» لا تدخل هذا المقام، وتبقى مسجلة منفصلة.', '',
      'المختار عند تثبيت النطاق: **27 بندًا جزئيًا و43 بندًا ناقصًا**. إصلاح التدرج والمنظور والأنماط جزء من هذه القائمة، لا بديل عنها. الوظائف الموجودة أصلًا تخضع لاختبارات عدم التراجع دون احتسابها ضمن الـ70.', '',
      '[الخطة](next-batch.md) · [سجل التنفيذ JSON](batch-01-ledger.json) · [CSV المهام](batch-01-tasks.csv) · [69 بندًا مؤجلًا](batch-02-deferred.csv)', '',
      'حالة كل مهمة وcommit وrun ودليل الشكل والأداء تُحدّث عند التنفيذ. ليس أي بند مكتملًا الآن بسبب اختياره. لا ينقل بند إلى «مكتمل» إذا بقيت وظائف مذكورة في اسمه أو فجواته غير منفذة؛ ولا يستبدل بند صعب ببند صغير لبلوغ العدد.', '']
for index, (group, numbers, gate) in enumerate(groups, start=1):
    items = [r for r in tasks if r['group']==group]
    md += [f'## {index} — {group} ({len(items)} بنود)', '', gate, '',
           '| الرقم | الوظيفة | خط الأساس | التنفيذ |', '|---|---|---|---|']
    for r in items:
        md.append('| '+' | '.join(str(r[k]).replace('|','/') for k in ['id','feature','baseline_status','execution_status'])+' |')
    md.append('')
md += ['## ترتيب العمل وبوابة الدفعة', '',
       'تثبيت إعادة إنتاج التدرج والمنظور ومشكلة cache، ثم بناء نموذج الفصل اللازم للسحب والقارئ والتصدير. يُنجز تصحيح النص والأنماط قبل اعتماد واجهاتهما، ثم يوصل التايبر والطبقات والرسم والإعدادات على النموذج النهائي. الدفعة كبيرة وتنفذ داخليًا على مراحل مترابطة؛ لا يعلن إنجاز 70 بندًا لمجرد بناء أول جزء.', '',
       'القبول النهائي: مقارنة مع الأصل لكل بند، واختبار الوظيفة والحفظ وإعادة الفتح والتراجع والتصدير؛ لقطات iPad في الاتجاهين وiPhone؛ الحفاظ على مصدر 800×15000؛ اكتمال الاختبارات وIPA غير موقع واحد. ما لا يمكن التحقق منه على جهاز فعلي يبقى موسومًا بذلك. دخول البريد والتعليق والمجتمع والتايبر الحالي لا تتراجع أثناء التوسعة.', '',
       'توافق أرشيفات الأصل وحزم أنماطه يتطلب عينات وقراءة صيغ حقيقية؛ استيراد ملفات Cookies وحده لا يحقق F019 أو F082. إعداد المنظف الذكي لا يُعد منفذًا إذا بقي مجرد مفتاح. لا تحل نقطة ∞ محل خدمة أصلية أو استحقاق خادم.']
(OUT / 'batch-01-scope.md').write_text('\n'.join(md)+'\n')
print(f'Batch 01: {len(tasks)}/139; deferred: {len(deferred)}; execution evidence preserved')
