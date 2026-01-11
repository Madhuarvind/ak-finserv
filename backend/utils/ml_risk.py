import numpy as np

from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler

import joblib
import os

import warnings

warnings.filterwarnings("ignore")

MODEL_PATH = "risk_model.pkl"
SCALER_PATH = "risk_scaler.pkl"


class RiskEngine:
    def __init__(self):
        self.model = None
        self.scaler = None
        self._load_or_train()

    def _load_or_train(self):
        """Loads existing model or trains a new one (Cold Start)"""
        if os.path.exists(MODEL_PATH) and os.path.exists(SCALER_PATH):
            try:
                self.model = joblib.load(MODEL_PATH)
                self.scaler = joblib.load(SCALER_PATH)
                print("DEBUG: Loaded existing ML Risk Model.")
            except Exception:
                print("DEBUG: Error loading model. Retraining...")
                self._train_cold_start()
        else:
            print("DEBUG: No model found. Training Cold Start Model...")
            self._train_cold_start()

    def _train_cold_start(self):
        """
        Trains a model on SYNTHETIC data representing industry standard patterns.
        This ensures the system works immediately without 1000s of historical records.
        Using Random Forest for robustness.
        """
        # Feature columns:
        # [missed_emis, max_days_overdue, days_since_last_pay, partial_payment_score, credit_utilization]

        # Generate 2000 synthetic records
        np.random.seed(42)
        # n_samples = 2000

        # Good Customers (Low Risk)
        good_missed = np.random.poisson(0.5, 1000)  # Mostly 0 or 1
        good_overdue = np.random.exponential(5, 1000)  # Mostly small overdue
        good_recency = np.random.exponential(10, 1000)  # Paid recently
        good_partial = np.random.choice([0, 5], 1000, p=[0.9, 0.1])  # Rarely partial
        good_util = np.random.normal(30, 10, 1000)  # 30% utilization

        X_good = np.column_stack(
            [good_missed, good_overdue, good_recency, good_partial, good_util]
        )
        y_good = np.zeros(1000)  # 0 = Low Risk

        # Bad Customers (High Risk)
        bad_missed = np.random.poisson(3, 1000) + 1  # At least 1, mostly more
        bad_overdue = np.random.normal(45, 15, 1000)  # Avg 45 days overdue
        bad_recency = np.random.normal(40, 20, 1000)  # Check days since pay
        bad_partial = np.random.choice([0, 15], 1000, p=[0.4, 0.6])  # Often partial
        bad_util = np.random.normal(80, 10, 1000)  # 80% utilization

        X_bad = np.column_stack(
            [bad_missed, bad_overdue, bad_recency, bad_partial, bad_util]
        )
        y_bad = np.ones(1000)  # 1 = High Risk

        X = np.vstack([X_good, X_bad])
        y = np.hstack([y_good, y_bad])

        # Train
        self.scaler = StandardScaler()
        X_scaled = self.scaler.fit_transform(X)

        # Random Forest is robust to outliers and non-linear patterns
        self.model = RandomForestClassifier(
            n_estimators=100, max_depth=5, random_state=42
        )
        self.model.fit(X_scaled, y)

        # Save
        joblib.dump(self.model, MODEL_PATH)
        joblib.dump(self.scaler, SCALER_PATH)
        print("DEBUG: Trained and saved Cold Start Risk Model.")

    def predict_risk(
        self,
        missed_emis,
        max_overdue_days,
        days_since_pay,
        partial_score,
        utilization_approx=50,
    ):
        """
        Returns:
            prob (float): 0.0 to 1.0 (Probability of Default)
            level (str): LOW / MEDIUM / HIGH
        """
        if not self.model or self.scaler is None:
            return 50.0, "UNKNOWN"

        features = np.array(
            [
                [
                    missed_emis,
                    max_overdue_days,
                    days_since_pay,
                    partial_score,
                    utilization_approx,
                ]
            ]
        )
        scaled = self.scaler.transform(features)

        # Probability of class 1 (Default/High Risk)
        prob = self.model.predict_proba(scaled)[0][1]

        if prob > 0.7:
            return prob * 100, "HIGH"
        elif prob > 0.4:
            return prob * 100, "MEDIUM"
        else:
            return prob * 100, "LOW"


# Singleton
risk_engine = RiskEngine()
