# خريطة الواجهات

21 وجهة Activity و13 عائلة Compose. قد تكون عائلة Compose داخل Activity أو نافذة؛ لا تُجمع الأعداد لإعلان عدد الشاشات. تضاف النوافذ واللوحات من فهرس layout. وجود الاسم في APK لا يثبت إمكان الوصول إليه بحسابنا.

| النوع | الأصل | الوظيفة | المقابل الحالي في iOS | البنود | دليل تشغيل الأصل |
|---|---|---|---|---|---|
| Activity | SplashActivity | البداية والحساب | WelcomeView / AccountView | F001 F002 F003 F004 F005 | 01-original-launch |
| Activity | CrashReportActivity | تقرير الانهيار | تنبيهات أخطاء فقط | F147 | لم توثق لقطة تشغيل لهذه الوجهة |
| Activity | FolatingWidgetDashboard | لوحة التايبر العائم | TyperLibraryView / TyperPanel داخل التطبيق | F028 F030 F043 | لم توثق لقطة تشغيل لهذه الوجهة |
| Activity | FontLibraryActivity | مكتبة الخطوط | FontLibraryView قائمة واحدة | F060 F084 F085 F086 | screens/23-font-tool |
| Activity | ArabicFontsActivity | الخطوط العربية | لا قسم مستقل | F084 | لم توثق لقطة تشغيل لهذه الوجهة |
| Activity | EnglishFontsActivity | الخطوط الإنجليزية | لا قسم مستقل | F084 | لم توثق لقطة تشغيل لهذه الوجهة |
| Activity | ImportedFontsActivity | الخطوط المستوردة | استيراد في FontLibraryView؛ إدارة ناقصة | F084 F085 F086 | لم توثق لقطة تشغيل لهذه الوجهة |
| Activity | ImportedStylesActivity | الأنماط المستوردة | لا مكتبة أنماط محفوظة | F081 F082 F086 | لم توثق لقطة تشغيل لهذه الوجهة |
| Activity | SettingsActivity | الإعدادات | SettingsView / TyperSettingsView | F141 F142 F143 F144 F145 F146 | 06-settings |
| Activity | StoreActivity | المتجر | غير منفذ | F136 | لم توثق لقطة تشغيل لهذه الوجهة |
| Activity | CopyActivity | نسخ واستقبال نص التايبر | حافظة في ChapterSourceView؛ ليس نفس المسار | F021 F033 F043 | لم توثق لقطة تشغيل لهذه الوجهة |
| Activity | ProjectsActivity | لوحة المشاريع والعمل | LibraryView | F008 F009 F010 F012 F014 | 03-projects-unauthenticated؛10-workspace |
| Activity | ProjectGalleryActivity | معرض صفحات المشروع | صور مستقلة ضمن LibraryView | F010 F011 F012 F023 F024 F025 | لم توثق لقطة تشغيل لهذه الوجهة |
| Activity | WebtoonScraperActivity | سحب الفصل | غير منفذ | F115 F116 F117 F118 | لم توثق لقطة تشغيل لهذه الوجهة |
| Activity | EditorActivity | المحرر | EditorView / StableCanvas / لوحات الأدوات | F045 F047 F048 F057 F058 F109 F110 | 23-editor-before-text؛24-text-tool؛24-text-handles؛28-editor-header-tools؛29-layers |
| Activity | ReaderActivity | القارئ | ReaderView صورة واحدة | F113 F114 | لم توثق لقطة تشغيل لهذه الوجهة |
| Activity | ImageCropActivity | قص الصورة | غير منفذ | F089 | لم توثق لقطة تشغيل لهذه الوجهة |
| Activity | ExportStudioActivity | استوديو التصدير | ExportSheet صفحة واحدة | F119 F120 F121 F122 F123 F124 F125 | لم توثق لقطة تشغيل لهذه الوجهة |
| Activity | TagMiniEditorActivity | محرر الوسم | TagStyleEditor حقول محدودة | F034 F035 F036 | لم توثق لقطة تشغيل لهذه الوجهة |
| Activity | CommunityActivity | المجتمع | CommunityView / PostDetailView | F126 F127 F128 F129 F130 F131 | لم توثق لقطة تشغيل لهذه الوجهة |
| Activity | CreatePostActivity | إنشاء منشور | غير منفذ | F129 | لم توثق لقطة تشغيل لهذه الوجهة |
| Compose؛ قد يكرر Activity | CommunityScreenKt | المجتمع | CommunityView | F126 F127 F128 F129 F130 F131 | يلزم تحقق الحالة الديناميكية |
| Compose؛ قد يكرر Activity | DailyRewardsScreenKt | المكافآت اليومية | غير منفذ | F135 | يلزم تحقق الحالة الديناميكية |
| Compose؛ قد يكرر Activity | ExportStudioScreenKt | استوديو التصدير | ExportSheet صفحة واحدة | F123 F124 | يلزم تحقق الحالة الديناميكية |
| Compose؛ قد يكرر Activity | FontsGridScreenKt | شبكة الخطوط | قائمة واحدة | F084 F085 | يلزم تحقق الحالة الديناميكية |
| Compose؛ قد يكرر Activity | InviteScreenKt | الدعوات | غير منفذ | F135 | يلزم تحقق الحالة الديناميكية |
| Compose؛ قد يكرر Activity | LeaderboardScreenKt | المتصدرون | غير منفذ | F134 | يلزم تحقق الحالة الديناميكية |
| Compose؛ قد يكرر Activity | MergeStudioDialogKt | استوديو الدمج | غير منفذ | F023 | يلزم تحقق الحالة الديناميكية |
| Compose؛ قد يكرر Activity | ProjectGalleryScreenKt | معرض الصفحات | غير منفذ كنموذج فصل | F010 F012 | يلزم تحقق الحالة الديناميكية |
| Compose؛ قد يكرر Activity | RadialUnlockDialogKt | القائمة الدائرية والاستحقاق | غير منفذ | F049 F136 | يلزم تحقق الحالة الديناميكية |
| Compose؛ قد يكرر Activity | ReaderStudioDialogKt | استوديو القارئ | صورة واحدة | F114 | يلزم تحقق الحالة الديناميكية |
| Compose؛ قد يكرر Activity | StoreScreenKt | المتجر | غير منفذ | F136 | يلزم تحقق الحالة الديناميكية |
| Compose؛ قد يكرر Activity | WatermarkStudioDialogKt | استوديو العلامة المائية | غير منفذ | F026 | يلزم تحقق الحالة الديناميكية |
| Compose؛ قد يكرر Activity | WebtoonScraperScreenKt | سحب الفصل | غير منفذ | F115 F116 F117 F118 | يلزم تحقق الحالة الديناميكية |

## الأزرار والحقول

[633 زرًا محتملًا ومدخلًا مع ربطه بميزة الأم](control-associations.csv). حالة ميزة الأم ليست شهادة لاختبار الزر. يشمل السجل الحجم الافتراضي والنص والتلميح والظهور ومصدر XML والإشارات البرمجية المباشرة. لا تُستبدل به لقطات الحالات الديناميكية.

[1090 عنصرًا بمعرف](original-ui-elements.csv)، [فهرس 110 ملفات layout](original-resource-inventory.json)، [70 accessor لإعدادات الأصل](original-preferences.csv). اللوحات التي لا تملك أزرار XML قد تحتوي واجهات Compose أو إجراءات منشأة برمجيًا.
