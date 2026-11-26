# Firestore Security Verification Plan

Run these checks in the Firebase Emulator Suite before deploying rules. Use one
student account, a different student account, and one staff account whose UID
has a document in the `staff` collection.

| Case | Actor | Expected result |
| --- | --- | --- |
| Create own `users/{uid}` document | Student | Allowed once, only at their own UID |
| Read another student's user document | Student | Denied |
| Read `staff/{ownUid}` | Staff | Allowed |
| Create a lost or found report | Signed-in student | Allowed with valid fields only |
| Add unknown fields to a report | Signed-in student | Denied |
| Read public reports | Signed-in user | Allowed |
| Read lost private detail, contacts, or found storage location | Student | Denied |
| Read private detail, contacts, or found storage location | Staff | Allowed |
| Read own claim | Claim owner | Allowed |
| Read another student's claim | Student | Denied |
| List claims by `ownerUid == request.auth.uid` | Claim owner | Allowed |
| List claims only by `studentId` | Student | Denied or rejected by query rules |
| Create a claim for an item with status `found` | Student | Allowed |
| Create a claim for a non-`found` item | Student | Denied |
| Update a claim status | Student | Denied |
| Approve, reject, mark ready, or mark returned | Staff | Allowed only in the valid order |
| Reject a pending claim | Staff | Claim becomes `rejected`; found item remains available |
| Read own notifications by `ownerUid` | Claim owner | Allowed |
| Read another student's notifications | Student | Denied |
| Create a notification or status event | Student | Denied |
| Create a notification or status event | Staff | Allowed with valid fields |

## Migration note

Older `found_reports` may still contain `storageLocation` in their public
documents. Rules cannot hide a field inside a readable Firestore document.
Before production use, migrate or delete those old records so the public
document no longer contains the field. New reports write storage locations to
`found_report_private`.

## Deployment

After the emulator checks pass, deploy only the rules:

```powershell
firebase deploy --only firestore:rules
```

Do not deploy until the team has confirmed the staff UID documents and tested
both student and staff accounts.
