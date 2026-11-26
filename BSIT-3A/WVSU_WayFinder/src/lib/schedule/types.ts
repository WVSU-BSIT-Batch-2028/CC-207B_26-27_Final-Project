export interface ClassSession {
  id: string;
  subject: string;
  weekday: number;       // 1 = Monday ... 7 = Sunday (Asia/Manila)
  start: string;         // "HH:MM" Manila time
  end: string;           // "HH:MM"
  roomCodeRaw: string;   // exactly what the student typed; never overwritten
  roomPlaceId?: string;  // set only when the code matched one place; otherwise "Room location unconfirmed"
  professor?: string;
  remindMinutes?: number; // undefined = no reminder
}
