import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";
import { getFunctions } from "firebase/functions";

const firebaseConfig = {
  apiKey: "AIzaSyBXjolvKWrsVAIDbxB5YdKPihWjWX1VE9U",
  authDomain: "my-bingo-mk.firebaseapp.com",
  projectId: "my-bingo-mk",
  storageBucket: "my-bingo-mk.firebasestorage.app",
  messagingSenderId: "717699093807",
  appId: "1:717699093807:web:7d4fac96899d2406bc3dda",
  measurementId: "G-55GWKC8E3V"
};

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
export const functions = getFunctions(app);
