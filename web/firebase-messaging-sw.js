importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyAuDyBrFQ4F4qlLL3lzN8s6_pegW_rCwxE",
  appId: "1:723690444111:web:a00377aceedb146599613a",
  messagingSenderId: "723690444111",
  projectId: "tourvia-8fa8c",
  authDomain: "tourvia-8fa8c.firebaseapp.com",
  storageBucket: "tourvia-8fa8c.firebasestorage.app",
  measurementId: "G-YQEWQM644B",
});

const messaging = firebase.messaging();

// Optional: handle background messages
messaging.onBackgroundMessage((message) => {
  console.log("[firebase-messaging-sw.js] Background message:", message);
});
