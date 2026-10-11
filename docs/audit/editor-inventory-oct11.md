# مقارنة المحرر المحدثة — 11 أكتوبر 2026

مرجع الكود: `06321b5663547547283b6373c0d092fcdebc03cb`؛ الأصل YTyper V4.5 بالـSHA الموثق في JSON. هذا جرد وظائف المحرر (102 بندًا من المصفوفة القديمة)، وليس نسبة اكتمال أو شهادة تطابق كل واجهة. لا يعدّل جرد الدفعة الموقوفة.

توزيع الحالات: 12 موجود، و36 موجود مع فروق موثقة، و16 جزئي، و35 ناقص، وبند يعتمد على خدمة خارجية، وبند يعتمد على الخادم، وبند له بديل iOS. هذا عدد بنود الجرد، ولا يقيس مقدار العمل أو نسبة مطابقة التطبيق.

## المتبقي الأوضح

- 12 تأثير نص متقدم، منها ECHO وLIQUID وCRIMSON_TEARS وFIRE_SHADER وGLASS_SHADER.
- 13 تأثير صورة مع لوحة تكديس وترتيب وتعطيل؛ RGB للنص لا يساوي تأثير RGB للصورة.
- تعديلات وفلاتر الصور، الفرشاة السحرية، قناع الصورة الحر ومسوداتها.
- القائمة الدائرية وتخصيصها، شبكة اللوحة، تثبيت الخلفية والتحريك بيد واحدة، وZen الكامل.
- أجزاء من قص/شفاء طبقة الصورة، منظورها، وأدوات الأشكال المتقدمة.
- نقل نموذج كشف التبييض الأصلي وتحقق أدائه على iOS؛ تنظيف النقوش لا يضمن إعادة الرسم المخفي حرفيًا.

## أشياء كانت ناقصة في الجرد القديم وأصبحت موجودة

الأنماط المخصصة، مجموعاتها واستيرادها وتصديرها؛ تنسيق نطاق وسطر؛ حدود متعددة وتدرجاتها؛ المنظور والشبكة للنص؛ مسطرة النص؛ تحويله إلى صورة وقناعه؛ فرشاة مخصصة وشفافيتها وأشكالها؛ الطمس والدلو؛ تحديد الطبقات وتجميعها ودمجها. خارج المحرر أصبحت عمليات الفصل متعدد الصفحات والدمج والتقسيم وPDF والقارئ والسحب من المواقع موجودة. لا ينبغي إعادة التخطيط لها كميزات مفقودة من الصفر.

## الأدلة التفصيلية

| البند | الأداة | الحالة الحالية | دليل iOS | الباقي |
|---|---|---|---|---|
| F045 | السحب والتكبير حتى رؤية البكسلات | موجود | CanvasHost; StableCanvas; LayerRenderer; LibraryStore; native tests | قياسات سرعة الجهاز الفعلي والمطابقة البصرية الشاملة ليست مثبتة. |
| F046 | أبعاد أصلية وتصدير لا يعتمد على المعاينة | موجود | CanvasHost; StableCanvas; LayerRenderer; LibraryStore; native tests | قياسات سرعة الجهاز الفعلي والمطابقة البصرية الشاملة ليست مثبتة. |
| F050 | التراجع والإعادة | موجود | CanvasHost; StableCanvas; LayerRenderer; LibraryStore; native tests | قياسات سرعة الجهاز الفعلي والمطابقة البصرية الشاملة ليست مثبتة. |
| F057 | إضافة وتحرير النص العربي RTL | موجود | CanvasHost; StableCanvas; LayerRenderer; LibraryStore; native tests | قياسات سرعة الجهاز الفعلي والمطابقة البصرية الشاملة ليست مثبتة. |
| F058 | المقابض التسعة وتحريك/تدوير/تمديد/نسخ/حذف | موجود | CanvasHost; StableCanvas; LayerRenderer; LibraryStore; native tests | قياسات سرعة الجهاز الفعلي والمطابقة البصرية الشاملة ليست مثبتة. |
| F047 | الرسم المباشر والسحب/التدوير السلس | جزئي | CanvasHost; LayerInteraction; live ink tests | استجابة حية موجودة، لكن ضمان السلاسة على جميع الأجهزة الضعيفة يحتاج قياسًا فعليًا. |
| F048 | شريط الأدوات يتبدل بحسب الأداة | موجود | EditorView tool/text/brush/object strips | الأدوات الفرعية تستبدل الشريط؛ تخصيصها ليس بكل تفاصيل الأصل. |
| F049 | القائمة الدائرية وتخصيص اختصاراتها | ناقص | EditorView; CanvasHost; EditorPreferences | القائمة الدائرية المخصصة، شبكة اللوحة، تثبيت الخلفية مع وضع تحريك بيد واحدة، وZen الكامل غير موجودة. |
| F051 | شبكة اللوحة وإعداداتها | ناقص | EditorView; CanvasHost; EditorPreferences | القائمة الدائرية المخصصة، شبكة اللوحة، تثبيت الخلفية مع وضع تحريك بيد واحدة، وZen الكامل غير موجودة. |
| F053 | قفل الخلفية وتثبيت التحريك بيد واحدة | ناقص | EditorView; CanvasHost; EditorPreferences | القائمة الدائرية المخصصة، شبكة اللوحة، تثبيت الخلفية مع وضع تحريك بيد واحدة، وZen الكامل غير موجودة. |
| F055 | وضع التركيز Zen واختصارات اللمس | ناقص | EditorView; CanvasHost; EditorPreferences | القائمة الدائرية المخصصة، شبكة اللوحة، تثبيت الخلفية مع وضع تحريك بيد واحدة، وZen الكامل غير موجودة. |
| F052 | المحاذاة المغناطيسية Snap | موجود | SnapAlignment; CanvasHost; WorkspaceSettingsView | التقاط المركز والحواف والزوايا موجود؛ دليل المحاذاة وأهداف الأصل الكاملة يحتاج مقارنة تفاعلية. |
| F054 | خلفية اللوحة وألوانها/شبكتها/صورتها وتمويهها | جزئي | CanvasHost backgroundColor 080808 | خلفية داكنة ثابتة؛ خيارات الصورة/الضبابية/شبكة الخلفية الأصلية غير موجودة. |
| F056 | قطارة لون من المركب النهائي | موجود | ColorSampler; CanvasHost; BrushFeedback; ColorLibraryStore | يقرأ المركب النهائي ويعرض اللون فوق الإصبع؛ الحالات المتقدمة تحتاج تجربة الجهاز. |
| F059 | محرر Inline مع لصق/نسخ/حروف كبيرة/صغيرة/تطويل وإرساء | موجود مع فروق | TextInspector; TextRanges; TextRaster; GradientControls; GeometryInspector; TextMaskEditing; TextConversion; StableCanvas | هذه الأدوات لم تعد مفقودة. المطابقة الدقيقة لكل مقبض وقالب، حجم الإدراج، والأداء مع كل خط وتشكيل ما زالت تتطلب المقارنة. أضيف التباعد السالب وRGB/Glitch؛ نتيجة اختبارات مصدر الدفعة موثقة في colors-effects-oct11.md. |
| F062 | تنسيق كلمة/مدى محدد Rich spans | موجود مع فروق | TextInspector; TextRanges; TextRaster; GradientControls; GeometryInspector; TextMaskEditing; TextConversion; StableCanvas | هذه الأدوات لم تعد مفقودة. المطابقة الدقيقة لكل مقبض وقالب، حجم الإدراج، والأداء مع كل خط وتشكيل ما زالت تتطلب المقارنة. أضيف التباعد السالب وRGB/Glitch؛ نتيجة اختبارات مصدر الدفعة موثقة في colors-effects-oct11.md. |
| F063 | تنسيق كل سطر والكشيدة والتوزيع | موجود مع فروق | TextInspector; TextRanges; TextRaster; GradientControls; GeometryInspector; TextMaskEditing; TextConversion; StableCanvas | هذه الأدوات لم تعد مفقودة. المطابقة الدقيقة لكل مقبض وقالب، حجم الإدراج، والأداء مع كل خط وتشكيل ما زالت تتطلب المقارنة. أضيف التباعد السالب وRGB/Glitch؛ نتيجة اختبارات مصدر الدفعة موثقة في colors-effects-oct11.md. |
| F064 | اللون والتدرج الأساسي | موجود مع فروق | TextInspector; TextRanges; TextRaster; GradientControls; GeometryInspector; TextMaskEditing; TextConversion; StableCanvas | هذه الأدوات لم تعد مفقودة. المطابقة الدقيقة لكل مقبض وقالب، حجم الإدراج، والأداء مع كل خط وتشكيل ما زالت تتطلب المقارنة. أضيف التباعد السالب وRGB/Glitch؛ نتيجة اختبارات مصدر الدفعة موثقة في colors-effects-oct11.md. |
| F065 | تدرجات متقدمة وتفاعلية وGradient Map | موجود مع فروق | TextInspector; TextRanges; TextRaster; GradientControls; GeometryInspector; TextMaskEditing; TextConversion; StableCanvas | هذه الأدوات لم تعد مفقودة. المطابقة الدقيقة لكل مقبض وقالب، حجم الإدراج، والأداء مع كل خط وتشكيل ما زالت تتطلب المقارنة. أضيف التباعد السالب وRGB/Glitch؛ نتيجة اختبارات مصدر الدفعة موثقة في colors-effects-oct11.md. |
| F067 | حدود إضافية/تدرج حدود/أشكال حدود وقوالب | موجود مع فروق | TextInspector; TextRanges; TextRaster; GradientControls; GeometryInspector; TextMaskEditing; TextConversion; StableCanvas | هذه الأدوات لم تعد مفقودة. المطابقة الدقيقة لكل مقبض وقالب، حجم الإدراج، والأداء مع كل خط وتشكيل ما زالت تتطلب المقارنة. أضيف التباعد السالب وRGB/Glitch؛ نتيجة اختبارات مصدر الدفعة موثقة في colors-effects-oct11.md. |
| F068 | خلفية النص مع استدارة/شفافية/حشو | موجود مع فروق | TextInspector; TextRanges; TextRaster; GradientControls; GeometryInspector; TextMaskEditing; TextConversion; StableCanvas | هذه الأدوات لم تعد مفقودة. المطابقة الدقيقة لكل مقبض وقالب، حجم الإدراج، والأداء مع كل خط وتشكيل ما زالت تتطلب المقارنة. أضيف التباعد السالب وRGB/Glitch؛ نتيجة اختبارات مصدر الدفعة موثقة في colors-effects-oct11.md. |
| F069 | الظل والنعومة والإزاحة والشفافية/تدرج الظل | موجود مع فروق | TextInspector; TextRanges; TextRaster; GradientControls; GeometryInspector; TextMaskEditing; TextConversion; StableCanvas | هذه الأدوات لم تعد مفقودة. المطابقة الدقيقة لكل مقبض وقالب، حجم الإدراج، والأداء مع كل خط وتشكيل ما زالت تتطلب المقارنة. أضيف التباعد السالب وRGB/Glitch؛ نتيجة اختبارات مصدر الدفعة موثقة في colors-effects-oct11.md. |
| F070 | الموضع والمحاذاة للوحة والنقل خطوة والقلب | موجود مع فروق | TextInspector; TextRanges; TextRaster; GradientControls; GeometryInspector; TextMaskEditing; TextConversion; StableCanvas | هذه الأدوات لم تعد مفقودة. المطابقة الدقيقة لكل مقبض وقالب، حجم الإدراج، والأداء مع كل خط وتشكيل ما زالت تتطلب المقارنة. أضيف التباعد السالب وRGB/Glitch؛ نتيجة اختبارات مصدر الدفعة موثقة في colors-effects-oct11.md. |
| F071 | تباعد الحروف والأسطر والتشكيل | موجود مع فروق | TextInspector; TextRanges; TextRaster; GradientControls; GeometryInspector; TextMaskEditing; TextConversion; StableCanvas | هذه الأدوات لم تعد مفقودة. المطابقة الدقيقة لكل مقبض وقالب، حجم الإدراج، والأداء مع كل خط وتشكيل ما زالت تتطلب المقارنة. أضيف التباعد السالب وRGB/Glitch؛ نتيجة اختبارات مصدر الدفعة موثقة في colors-effects-oct11.md. |
| F072 | الأبعاد والبروز ثلاثي الأبعاد | موجود مع فروق | TextInspector; TextRanges; TextRaster; GradientControls; GeometryInspector; TextMaskEditing; TextConversion; StableCanvas | هذه الأدوات لم تعد مفقودة. المطابقة الدقيقة لكل مقبض وقالب، حجم الإدراج، والأداء مع كل خط وتشكيل ما زالت تتطلب المقارنة. أضيف التباعد السالب وRGB/Glitch؛ نتيجة اختبارات مصدر الدفعة موثقة في colors-effects-oct11.md. |
| F073 | المنظور الرباعي والشبكة الحرة على الصورة | موجود مع فروق | TextInspector; TextRanges; TextRaster; GradientControls; GeometryInspector; TextMaskEditing; TextConversion; StableCanvas | هذه الأدوات لم تعد مفقودة. المطابقة الدقيقة لكل مقبض وقالب، حجم الإدراج، والأداء مع كل خط وتشكيل ما زالت تتطلب المقارنة. أضيف التباعد السالب وRGB/Glitch؛ نتيجة اختبارات مصدر الدفعة موثقة في colors-effects-oct11.md. |
| F075 | الخامات: استيراد وتحجيم ودوران وإزاحة | موجود مع فروق | TextInspector; TextRanges; TextRaster; GradientControls; GeometryInspector; TextMaskEditing; TextConversion; StableCanvas | هذه الأدوات لم تعد مفقودة. المطابقة الدقيقة لكل مقبض وقالب، حجم الإدراج، والأداء مع كل خط وتشكيل ما زالت تتطلب المقارنة. أضيف التباعد السالب وRGB/Glitch؛ نتيجة اختبارات مصدر الدفعة موثقة في colors-effects-oct11.md. |
| F076 | شفافية النص الداخلية ومزج الطبقة | موجود مع فروق | TextInspector; TextRanges; TextRaster; GradientControls; GeometryInspector; TextMaskEditing; TextConversion; StableCanvas | هذه الأدوات لم تعد مفقودة. المطابقة الدقيقة لكل مقبض وقالب، حجم الإدراج، والأداء مع كل خط وتشكيل ما زالت تتطلب المقارنة. أضيف التباعد السالب وRGB/Glitch؛ نتيجة اختبارات مصدر الدفعة موثقة في colors-effects-oct11.md. |
| F077 | تلاشي باتجاه/مدى كأداة مستقلة | موجود مع فروق | TextInspector; TextRanges; TextRaster; GradientControls; GeometryInspector; TextMaskEditing; TextConversion; StableCanvas | هذه الأدوات لم تعد مفقودة. المطابقة الدقيقة لكل مقبض وقالب، حجم الإدراج، والأداء مع كل خط وتشكيل ما زالت تتطلب المقارنة. أضيف التباعد السالب وRGB/Glitch؛ نتيجة اختبارات مصدر الدفعة موثقة في colors-effects-oct11.md. |
| F078 | المسطرة والتوسيط السحري | موجود مع فروق | TextInspector; TextRanges; TextRaster; GradientControls; GeometryInspector; TextMaskEditing; TextConversion; StableCanvas | هذه الأدوات لم تعد مفقودة. المطابقة الدقيقة لكل مقبض وقالب، حجم الإدراج، والأداء مع كل خط وتشكيل ما زالت تتطلب المقارنة. أضيف التباعد السالب وRGB/Glitch؛ نتيجة اختبارات مصدر الدفعة موثقة في colors-effects-oct11.md. |
| F079 | تحويل النص إلى PNG/طبقة صورة | موجود مع فروق | TextInspector; TextRanges; TextRaster; GradientControls; GeometryInspector; TextMaskEditing; TextConversion; StableCanvas | هذه الأدوات لم تعد مفقودة. المطابقة الدقيقة لكل مقبض وقالب، حجم الإدراج، والأداء مع كل خط وتشكيل ما زالت تتطلب المقارنة. أضيف التباعد السالب وRGB/Glitch؛ نتيجة اختبارات مصدر الدفعة موثقة في colors-effects-oct11.md. |
| F080 | مسح/استرجاع النص بقناع مرسوم | موجود مع فروق | TextInspector; TextRanges; TextRaster; GradientControls; GeometryInspector; TextMaskEditing; TextConversion; StableCanvas | هذه الأدوات لم تعد مفقودة. المطابقة الدقيقة لكل مقبض وقالب، حجم الإدراج، والأداء مع كل خط وتشكيل ما زالت تتطلب المقارنة. أضيف التباعد السالب وRGB/Glitch؛ نتيجة اختبارات مصدر الدفعة موثقة في colors-effects-oct11.md. |
| F074 | التشويه Warp كأداة مستقلة | جزئي | LayerRenderer warp fallback; TextInspector effects | تشويه الميل موجود؛ لوحة وخوارزمية Warp الخاصة بالأصل ليست مطابقة. |
| F081 | أنماط نص محفوظة وإنشاء نمط من المحدد | موجود مع فروق | StyleStore; StyleLibraryView; SavedStyleDesigner; ReferenceStyleImport; StyleComponents | إنشاء ومحرر كامل ومجلدات ومفضلة ووسوم وتصدير/استيراد ونسخ جزئي موجودة. القطارة الدائرية وآخر نمط بضغطة واحدة وتوافق كل خصائص حزم الأصل غير مثبتة. |
| F082 | استيراد/تصدير حزم أنماط ووسوم | موجود مع فروق | StyleStore; StyleLibraryView; SavedStyleDesigner; ReferenceStyleImport; StyleComponents | إنشاء ومحرر كامل ومجلدات ومفضلة ووسوم وتصدير/استيراد ونسخ جزئي موجودة. القطارة الدائرية وآخر نمط بضغطة واحدة وتوافق كل خصائص حزم الأصل غير مثبتة. |
| F083 | قطارة النمط ونسخ آخر نمط | موجود مع فروق | StyleStore; StyleLibraryView; SavedStyleDesigner; ReferenceStyleImport; StyleComponents | إنشاء ومحرر كامل ومجلدات ومفضلة ووسوم وتصدير/استيراد ونسخ جزئي موجودة. القطارة الدائرية وآخر نمط بضغطة واحدة وتوافق كل خصائص حزم الأصل غير مثبتة. |
| F084 | مكتبة خطوط عربية/إنجليزية/مستوردة بفلاتر ومجموعات | موجود | FontLibraryView; FontPackage | فلاتر عربية/إنجليزية ومفضلة وآخر استخدام واستيراد وتصدير موجودة؛ مجموعات الأصل التفصيلية تحتاج مقارنة. |
| F085 | تصدير الخطوط/حزمها وحذف المخصصة | موجود | FontLibraryView; FontPackage | فلاتر عربية/إنجليزية ومفضلة وآخر استخدام واستيراد وتصدير موجودة؛ مجموعات الأصل التفصيلية تحتاج مقارنة. |
| F086 | مزامنة الخطوط والأنماط وGoogle Drive | اعتماد خارجي | لا يوجد اتصال Google Drive للمزامنة في iOS | مزامنة الخطوط والأنماط تحتاج تكامل Drive رسمي؛ النسخ المحلي ليس مزامنة سحابية. |
| F087 | إضافة صورة كطبقة مع حفظ المصدر | موجود | EditorView Photos picker; LayerInteraction | إضافة وتحريك وتحويل/نسخ/حذف الصورة موجودة؛ النص يبقى منفصلًا. |
| F088 | موضع الصورة/دورانها/تمديدها/نسخها وحذفها | موجود | EditorView Photos picker; LayerInteraction | إضافة وتحريك وتحويل/نسخ/حذف الصورة موجودة؛ النص يبقى منفصلًا. |
| F089 | قص الصورة/قص الخلفية والشفاء بقصّ المنطقة | جزئي | PageOperations cropped/canvasResized; BackgroundReplacement; EditorView | قص/تغيير لوحة الفصل واستبدال الأصل موجود؛ أداة قص طبقة صورة وشفاء من قص مطابق للأصل ناقصة. |
| F090 | استبدال الخلفية وتغيير مقاسها | جزئي | PageOperations cropped/canvasResized; BackgroundReplacement; EditorView | قص/تغيير لوحة الفصل واستبدال الأصل موجود؛ أداة قص طبقة صورة وشفاء من قص مطابق للأصل ناقصة. |
| F091 | منظور الصورة وعتامتها ومزجها | جزئي | EditorView object opacity/position; LayerRenderer | عتامة ومزج وتحويل الصورة موجود؛ منظور رباعي/شبكي خاص بالصورة غير موصل كأداة كاملة. |
| F092 | سطوع/تباين/تشبع/تعريض/حرارة/صبغة/ظل/إضاءة/درجة/حواف | ناقص | No image adjustment/effect stack model or ImageEffectsPanel equivalent in App | ضبط وفلاتر وتكديس تأثيرات الصور، الفرشاة السحرية، قناع حر لمسح/استرجاع الصورة، ومسودات الصور غير مكتملة/غير موجودة. قناع النص منفصل. |
| F093 | فلاتر الصورة وقوالبها | ناقص | No image adjustment/effect stack model or ImageEffectsPanel equivalent in App | ضبط وفلاتر وتكديس تأثيرات الصور، الفرشاة السحرية، قناع حر لمسح/استرجاع الصورة، ومسودات الصور غير مكتملة/غير موجودة. قناع النص منفصل. |
| F094 | تأثيرات الصورة: 13 نوعًا مع تكديس وترتيب/تعطيل | ناقص | No image adjustment/effect stack model or ImageEffectsPanel equivalent in App | ضبط وفلاتر وتكديس تأثيرات الصور، الفرشاة السحرية، قناع حر لمسح/استرجاع الصورة، ومسودات الصور غير مكتملة/غير موجودة. قناع النص منفصل. |
| F095 | الفرشاة السحرية: مؤثر موضعي بقناع | ناقص | No image adjustment/effect stack model or ImageEffectsPanel equivalent in App | ضبط وفلاتر وتكديس تأثيرات الصور، الفرشاة السحرية، قناع حر لمسح/استرجاع الصورة، ومسودات الصور غير مكتملة/غير موجودة. قناع النص منفصل. |
| F096 | مسح واسترجاع الصورة بقناع | ناقص | No image adjustment/effect stack model or ImageEffectsPanel equivalent in App | ضبط وفلاتر وتكديس تأثيرات الصور، الفرشاة السحرية، قناع حر لمسح/استرجاع الصورة، ومسودات الصور غير مكتملة/غير موجودة. قناع النص منفصل. |
| F097 | مسودات الصور وإدارة المحفوظات | ناقص | No image adjustment/effect stack model or ImageEffectsPanel equivalent in App | ضبط وفلاتر وتكديس تأثيرات الصور، الفرشاة السحرية، قناع حر لمسح/استرجاع الصورة، ومسودات الصور غير مكتملة/غير موجودة. قناع النص منفصل. |
| F098 | الأشكال وفقاعات الكلام الأساسية | جزئي | LayerRenderer.shapePath; EditorView shapes/text inspector | أشكال أساسية ولون وحدود وتحويل وعتامة موجودة؛ منظور ومسح الشكل المتقدم وبعض فقاعات الأصل ناقصة. |
| F099 | أدوات الأشكال: لون/موضع/منظور/مسح/شفافية | جزئي | LayerRenderer.shapePath; EditorView shapes/text inspector | أشكال أساسية ولون وحدود وتحويل وعتامة موجودة؛ منظور ومسح الشكل المتقدم وبعض فقاعات الأصل ناقصة. |
| F100 | فرشاة صلبة/مائية/مضيئة وحجم ولون | موجود مع فروق | BrushRenderer; AuxiliaryViews; CanvasHost; SmudgeSession; FillBucket; Cleaner; CleaningPreview | الفرشاة/خامة مخصصة/شفافية/أشكال/ممحات/طمس/دلو/تنظيف/معاينة موجودة. أدوات الأصل الإضافية والتكافؤ البصري لكل فرشاة لا تزال غير مثبتة. |
| F101 | فرشاة SOFT/MARKER/CUSTOM_TEXTURE | موجود مع فروق | BrushRenderer; AuxiliaryViews; CanvasHost; SmudgeSession; FillBucket; Cleaner; CleaningPreview | الفرشاة/خامة مخصصة/شفافية/أشكال/ممحات/طمس/دلو/تنظيف/معاينة موجودة. أدوات الأصل الإضافية والتكافؤ البصري لكل فرشاة لا تزال غير مثبتة. |
| F102 | شفافية الفرشاة وفرشاة Plus | موجود مع فروق | BrushRenderer; AuxiliaryViews; CanvasHost; SmudgeSession; FillBucket; Cleaner; CleaningPreview | الفرشاة/خامة مخصصة/شفافية/أشكال/ممحات/طمس/دلو/تنظيف/معاينة موجودة. أدوات الأصل الإضافية والتكافؤ البصري لكل فرشاة لا تزال غير مثبتة. |
| F103 | ممحاة الرسم ومسح اللوحة | موجود مع فروق | BrushRenderer; AuxiliaryViews; CanvasHost; SmudgeSession; FillBucket; Cleaner; CleaningPreview | الفرشاة/خامة مخصصة/شفافية/أشكال/ممحات/طمس/دلو/تنظيف/معاينة موجودة. أدوات الأصل الإضافية والتكافؤ البصري لكل فرشاة لا تزال غير مثبتة. |
| F104 | الرسم: مستطيل/دائرة/خط مستقيم وتعبئة | موجود مع فروق | BrushRenderer; AuxiliaryViews; CanvasHost; SmudgeSession; FillBucket; Cleaner; CleaningPreview | الفرشاة/خامة مخصصة/شفافية/أشكال/ممحات/طمس/دلو/تنظيف/معاينة موجودة. أدوات الأصل الإضافية والتكافؤ البصري لكل فرشاة لا تزال غير مثبتة. |
| F105 | طمس Smudge وحجم وقوة | موجود مع فروق | BrushRenderer; AuxiliaryViews; CanvasHost; SmudgeSession; FillBucket; Cleaner; CleaningPreview | الفرشاة/خامة مخصصة/شفافية/أشكال/ممحات/طمس/دلو/تنظيف/معاينة موجودة. أدوات الأصل الإضافية والتكافؤ البصري لكل فرشاة لا تزال غير مثبتة. |
| F106 | دلو التعبئة Fill Bucket | موجود مع فروق | BrushRenderer; AuxiliaryViews; CanvasHost; SmudgeSession; FillBucket; Cleaner; CleaningPreview | الفرشاة/خامة مخصصة/شفافية/أشكال/ممحات/طمس/دلو/تنظيف/معاينة موجودة. أدوات الأصل الإضافية والتكافؤ البصري لكل فرشاة لا تزال غير مثبتة. |
| F107 | تنظيف منطقة OpenCV Inpaint | موجود مع فروق | BrushRenderer; AuxiliaryViews; CanvasHost; SmudgeSession; FillBucket; Cleaner; CleaningPreview | الفرشاة/خامة مخصصة/شفافية/أشكال/ممحات/طمس/دلو/تنظيف/معاينة موجودة. أدوات الأصل الإضافية والتكافؤ البصري لكل فرشاة لا تزال غير مثبتة. |
| F108 | معاينة التنظيف/تنويعات/اعتماد/إلغاء | موجود مع فروق | BrushRenderer; AuxiliaryViews; CanvasHost; SmudgeSession; FillBucket; Cleaner; CleaningPreview | الفرشاة/خامة مخصصة/شفافية/أشكال/ممحات/طمس/دلو/تنظيف/معاينة موجودة. أدوات الأصل الإضافية والتكافؤ البصري لكل فرشاة لا تزال غير مثبتة. |
| F109 | طبقات نص/صورة/شكل/رسم منفصلة | موجود مع فروق | LayerOrdering; LayerOperations; LayerSheet; AuxiliaryViews | فلاتر ومعاينة وتحديد ودمج وتسطيح وتجميع موجودة. المجموعات المسطحة لا تثبت مجلدات متداخلة أو أقنعة قص مطابقة. |
| F110 | ترتيب/إظهار/إخفاء/قفل/نسخ/حذف/شفافية/مزج | موجود مع فروق | LayerOrdering; LayerOperations; LayerSheet; AuxiliaryViews | فلاتر ومعاينة وتحديد ودمج وتسطيح وتجميع موجودة. المجموعات المسطحة لا تثبت مجلدات متداخلة أو أقنعة قص مطابقة. |
| F111 | فلاتر أنواع الطبقات ومعاينة مكبرة/تحديد متعدد | موجود مع فروق | LayerOrdering; LayerOperations; LayerSheet; AuxiliaryViews | فلاتر ومعاينة وتحديد ودمج وتسطيح وتجميع موجودة. المجموعات المسطحة لا تثبت مجلدات متداخلة أو أقنعة قص مطابقة. |
| F112 | دمج طبقات/تسطيح/تجميع | موجود مع فروق | LayerOrdering; LayerOperations; LayerSheet; AuxiliaryViews | فلاتر ومعاينة وتحديد ودمج وتسطيح وتجميع موجودة. المجموعات المسطحة لا تثبت مجلدات متداخلة أو أقنعة قص مطابقة. |
| F040 | القنص: تحليل الفقاعة وتحديد الأهداف بالترتيب | موجود مع فروق | SniperDetector; BubbleBoundary.hpp; TyperStore.place; ContourTypesetter | تحديد وتوزيع وتنسيق موجودة. الحدود المفتوحة والزخارف التي تشبه محيط فقاعة قد تتطلب تحديدًا يدويًا. |
| F041 | توزيع عدة فقاعات على أهداف القنص | موجود مع فروق | SniperDetector; BubbleBoundary.hpp; TyperStore.place; ContourTypesetter | تحديد وتوزيع وتنسيق موجودة. الحدود المفتوحة والزخارف التي تشبه محيط فقاعة قد تتطلب تحديدًا يدويًا. |
| F042 | ذخيرة القنص وربط الاستحقاقات والحساب | اعتماد خادم | ReferenceService entitlements | لا تُغيّر ذخيرة أو نقاط الخادم؛ الأدوات المحلية مجانية. |
| F043 | نافذة عائمة فوق التطبيقات | بديل iOS | TyperPanel | نافذة داخل التطبيق؛ iOS لا يسمح بنافذة عامة فوق التطبيقات الأخرى. |
| F150 | BLUR | جزئي | TextRaster; LayerRenderer; TextArtRenderer; TextInspector | تنفيذ محلي موجود؛ التكافؤ البصري والخوارزمي مع كل تأثير الأصل غير مثبت. RGB/شرائح Glitch مستلهمان من فيديو ibisPaint. |
| F151 | GLITCH | جزئي | TextArtRenderer.swift; TextInspector.swift; ColorAndReferenceEffectsTests.swift | أضيف Glitch بشرائح أفقية قابلة لضبط الارتفاع والإزاحة وإزاحة اللون وتوزيع ثابت قابل للتغيير، دون تحويل النص إلى صورة. مطابقة كل معامل ونتيجة تأثير GLITCH في YTyper تحتاج مقارنة تفاعلية مباشرة؛ هذه الدفعة تطابق نوع المؤثر في فيديو ibisPaint. |
| F152 | SLICE | جزئي | TextRaster; LayerRenderer; TextArtRenderer; TextInspector | تنفيذ محلي موجود؛ التكافؤ البصري والخوارزمي مع كل تأثير الأصل غير مثبت. RGB/شرائح Glitch مستلهمان من فيديو ibisPaint. |
| F153 | NEON | جزئي | TextRaster; LayerRenderer; TextArtRenderer; TextInspector | تنفيذ محلي موجود؛ التكافؤ البصري والخوارزمي مع كل تأثير الأصل غير مثبت. RGB/شرائح Glitch مستلهمان من فيديو ibisPaint. |
| F154 | FADE | جزئي | TextRaster; LayerRenderer; TextArtRenderer; TextInspector | تنفيذ محلي موجود؛ التكافؤ البصري والخوارزمي مع كل تأثير الأصل غير مثبت. RGB/شرائح Glitch مستلهمان من فيديو ibisPaint. |
| F155 | WARP | جزئي | TextRaster; LayerRenderer; TextArtRenderer; TextInspector | تنفيذ محلي موجود؛ التكافؤ البصري والخوارزمي مع كل تأثير الأصل غير مثبت. RGB/شرائح Glitch مستلهمان من فيديو ibisPaint. |
| F156 | SHADOW | جزئي | TextRaster; LayerRenderer; TextArtRenderer; TextInspector | تنفيذ محلي موجود؛ التكافؤ البصري والخوارزمي مع كل تأثير الأصل غير مثبت. RGB/شرائح Glitch مستلهمان من فيديو ibisPaint. |
| F157 | ERROR | جزئي | TextRaster; LayerRenderer; TextArtRenderer; TextInspector | تنفيذ محلي موجود؛ التكافؤ البصري والخوارزمي مع كل تأثير الأصل غير مثبت. RGB/شرائح Glitch مستلهمان من فيديو ibisPaint. |
| F158 | ECHO | ناقص | TextEffect enum lacks these cases | تأثيرات النص المتقدمة/shaders غير موجودة في iOS. |
| F159 | LIQUID | ناقص | TextEffect enum lacks these cases | تأثيرات النص المتقدمة/shaders غير موجودة في iOS. |
| F160 | CRIMSON_TEARS | ناقص | TextEffect enum lacks these cases | تأثيرات النص المتقدمة/shaders غير موجودة في iOS. |
| F161 | ABYSSAL | ناقص | TextEffect enum lacks these cases | تأثيرات النص المتقدمة/shaders غير موجودة في iOS. |
| F162 | PANIC_TREMOR | ناقص | TextEffect enum lacks these cases | تأثيرات النص المتقدمة/shaders غير موجودة في iOS. |
| F163 | FIRE_SHADER | ناقص | TextEffect enum lacks these cases | تأثيرات النص المتقدمة/shaders غير موجودة في iOS. |
| F164 | GLASS_SHADER | ناقص | TextEffect enum lacks these cases | تأثيرات النص المتقدمة/shaders غير موجودة في iOS. |
| F165 | AURA_SHADER | ناقص | TextEffect enum lacks these cases | تأثيرات النص المتقدمة/shaders غير موجودة في iOS. |
| F166 | NEBULA_SHADER | ناقص | TextEffect enum lacks these cases | تأثيرات النص المتقدمة/shaders غير موجودة في iOS. |
| F167 | PLASMA_SHADER | ناقص | TextEffect enum lacks these cases | تأثيرات النص المتقدمة/shaders غير موجودة في iOS. |
| F168 | HOLOGRAPHIC_SHADER | ناقص | TextEffect enum lacks these cases | تأثيرات النص المتقدمة/shaders غير موجودة في iOS. |
| F169 | ELECTRIC_SHADER | ناقص | TextEffect enum lacks these cases | تأثيرات النص المتقدمة/shaders غير موجودة في iOS. |
| F170 | BLUR | ناقص | No image effect stack | تأثيرات الصورة ليست تأثيرات النص؛ إضافة RGB للنص لا تنجز CHROMATIC للصورة. |
| F171 | CHROMATIC | ناقص | No image effect stack | تأثيرات الصورة ليست تأثيرات النص؛ إضافة RGB للنص لا تنجز CHROMATIC للصورة. |
| F172 | GLITCH | ناقص | No image effect stack | تأثيرات الصورة ليست تأثيرات النص؛ إضافة RGB للنص لا تنجز CHROMATIC للصورة. |
| F173 | VIGNETTE | ناقص | No image effect stack | تأثيرات الصورة ليست تأثيرات النص؛ إضافة RGB للنص لا تنجز CHROMATIC للصورة. |
| F174 | GRAIN | ناقص | No image effect stack | تأثيرات الصورة ليست تأثيرات النص؛ إضافة RGB للنص لا تنجز CHROMATIC للصورة. |
| F175 | GLOW | ناقص | No image effect stack | تأثيرات الصورة ليست تأثيرات النص؛ إضافة RGB للنص لا تنجز CHROMATIC للصورة. |
| F176 | PIXELATE | ناقص | No image effect stack | تأثيرات الصورة ليست تأثيرات النص؛ إضافة RGB للنص لا تنجز CHROMATIC للصورة. |
| F177 | HALFTONE | ناقص | No image effect stack | تأثيرات الصورة ليست تأثيرات النص؛ إضافة RGB للنص لا تنجز CHROMATIC للصورة. |
| F178 | SLICE | ناقص | No image effect stack | تأثيرات الصورة ليست تأثيرات النص؛ إضافة RGB للنص لا تنجز CHROMATIC للصورة. |
| F179 | FADE | ناقص | No image effect stack | تأثيرات الصورة ليست تأثيرات النص؛ إضافة RGB للنص لا تنجز CHROMATIC للصورة. |
| F180 | DUOTONE | ناقص | No image effect stack | تأثيرات الصورة ليست تأثيرات النص؛ إضافة RGB للنص لا تنجز CHROMATIC للصورة. |
| F181 | MIRROR | ناقص | No image effect stack | تأثيرات الصورة ليست تأثيرات النص؛ إضافة RGB للنص لا تنجز CHROMATIC للصورة. |
| F182 | OUTLINE | ناقص | No image effect stack | تأثيرات الصورة ليست تأثيرات النص؛ إضافة RGB للنص لا تنجز CHROMATIC للصورة. |

الأدلة الأصلية لكل بند موجودة في [JSON](editor-inventory-oct11.json)، ومصدر الجرد الكامل هو [182 بندًا](feature-parity.json). الحالات أعلاه مراجعة كود؛ نتيجة التشغيل الجديدة ستسجّل في [سجل هذه الدفعة](colors-effects-oct11.md).
