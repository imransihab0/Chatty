# Privacy Policy for Chatty

**Last updated:** November 8, 2026

**Chatty** ("we", "our", or "us") is dedicated to protecting your privacy. This Privacy Policy outlines how your personal data is collected, used, and safeguarded when using the Chatty mobile application.

---

## 1. Information We Collect

### A. Account Information
When you sign in using Google Sign-In or email authentication, we receive basic profile information:
- Your name
- Your email address
- Your profile picture URL

### B. Messages & Media
- **Chat Messages**: Encrypted in transit and stored securely on Google Cloud Firestore to facilitate real-time delivery and sync across your devices.
- **Photos & Media**: Uploaded to secure Cloudflare R2 / Firebase Storage with access limited to conversation participants.
- **Voice Notes**: Audio recordings uploaded securely to allow playback between conversation members.

### C. Device & Operational Data
- **Device Identifiers**: Push notification tokens used solely to deliver real-time notifications for incoming messages.
- **Presence & Status**: Real-time online/active indicators to show contacts when you are active.

---

## 2. Device Permissions Used

Chatty requests only the permissions necessary to provide messaging features:
- **Camera**: To capture and send photos directly within chats.
- **Microphone**: To record and transmit voice notes.
- **Photos / Media Storage**: To select and share photos from your gallery.
- **Notifications**: To alert you of incoming messages and calls.

You may grant or revoke these permissions at any time in your device settings.

---

## 3. How We Use Your Information

We use the information collected solely to:
- Provide, operate, and maintain real-time messaging services.
- Authenticate user identity and secure accounts.
- Deliver push notifications for new messages.
- Prevent abuse, spam, and security breaches.

We **do not** sell, rent, or monetize your personal data. We **do not** display third-party advertisements or track you across other applications.

---

## 4. Data Storage & Security

- **Encryption**: All network communication between the app and our backend servers is encrypted using Transport Layer Security (TLS/HTTPS).
- **Service Providers**: We utilize industry-standard cloud providers:
  - **Google Firebase**: Authentication, Cloud Firestore, and Cloud Functions.
  - **Cloudflare R2**: Fast, encrypted object storage for media and voice notes.

---

## 5. Your Rights & Data Deletion

You have full control over your information:
- **Message Deletion**: Deleting a message removes it from both your device and the database.
- **Account Deletion**: You can request full deletion of your account and associated data by contacting us or using in-app settings.

---

## 6. Children's Privacy

Chatty is not directed to children under the age of 13. We do not knowingly collect personal identifiable information from children under 13.

---

## 7. Changes to This Policy

We may update our Privacy Policy periodically. We will notify you of any changes by posting the new Privacy Policy on this page.

---

## 8. Contact Us

If you have any questions or suggestions regarding this Privacy Policy, please contact:
- **Developer**: Imran Sihab
- **GitHub**: [https://github.com/imransihab0/Chatty](https://github.com/imransihab0/Chatty)
