# رد مراجعة Apple — Guideline 2.1 (Information Needed)
انسخ النص الإنجليزي أدناه في «Reply to App Review»، وألصقه أيضاً في App Review Information ← Notes. أرفق فيديو التسجيل مع الرد.

---

Hello, thank you for reviewing our app.

1. Screen recording: attached. It was recorded on a physical iPhone running the latest iOS. It starts from launching the app and shows the typical user flow: signing in with a one-time code sent by email, the family dashboard and its main features (members, tasks, rewards), and account deletion (Settings → Delete family / Delete my account). The app has no paid content and no in-app purchases.

2. Purpose and target audience: "مهام أسرتي" (My Family Tasks) is an Arabic-language app for families. A parent creates a family and adds household tasks with points. Children and other members complete the tasks, the parent approves them, and members earn points, levels and rewards that the parent defines. The problem it solves: it makes sharing housework fair and motivating, and it replaces paper charts and repeated reminders. Target audience: parents and family members. Children use the app only inside a family that a parent created and manages.

3. Access instructions:
- Quickest way, with no account: on the first screen, tap "تجربة سريعة بأسرة جاهزة" (Quick demo with a sample family). This opens a ready-made family with sample data. Demo data stays on the device only.
- Full account: tap "مسؤول الأسرة" (Family admin), enter a family name, your name and any email address you can access. A one-time 6-digit code is sent to that email. There is no password. After you sign in, create a family and add members, tasks and rewards.
- Account deletion: tap ⚙️ Settings (الإعدادات). The family owner sees "حذف الأسرة كاملة" (Delete the entire family), which deletes the account, the family and all its data. Other members see "حذف حسابي" (Delete my account).

4. External services: Google Firebase (Authentication, Cloud Firestore database, Cloud Messaging for notifications); our own backend API, which handles sign-in codes and points logic; and an email service (Gmail SMTP) that sends the sign-in codes. There is no advertising, no analytics SDK, no payment processor, and no AI service.

5. Regional differences: the app works the same way in all regions. The interface is in Arabic.

6. Regulated industry: not applicable. There is no protected third-party material. User content (tasks, optional completion photos) is private. Only members of the same family can see it, and it is never shown publicly. Only the family admin can add or remove members.

Thank you.
