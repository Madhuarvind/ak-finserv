import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler

MODEL_PATH_ISO = "worker_anomaly_model.pkl"
MODEL_PATH_KMEANS = "worker_cluster_model.pkl"


class WorkerIntelligence:
    def __init__(self):
        self.scaler = StandardScaler()
        # We don't necessarily need to persist these for small batches,
        # retraining on live data per request is often better for dynamic dashboards
        # unless dataset is huge. For < 100 agents, live training is ms.

    def analyze_workforce(self, agent_data_list):
        """
        Input: List of dicts: [
            {'agent_id': 1, 'amount': 50000, 'count': 50, 'batch_events': 2, 'flagged': 0},
            ...
        ]

        Outputs:
        - DataFrame with 'anomaly_score', 'is_anomaly', 'cluster_label'
        """
        if not agent_data_list:
            return {}

        df = pd.DataFrame(agent_data_list)
        if df.empty:
            return {}

        # Features for analysis
        # 1. Volume (Amount)
        # 2. Activity (Count)
        # 3. Risk (Batch Events + Flagged)

        # Prepare Feature Matrix
        X = df[["amount", "count", "batch_events", "flagged"]].copy()
        X["risk_index"] = (X["batch_events"] * 2) + (X["flagged"] * 5)  # Weighted risk

        # Select features for ML
        # Anomaly Detection Features: Focus on pattern irregularity
        X_anomaly = X[["count", "risk_index", "amount"]]

        # Fill NaN
        X_anomaly = X_anomaly.fillna(0)

        # --- 1. Anomaly Detection (Isolation Forest) ---
        # Detects agents whose behavior significantly deviates from the norm
        # e.g. Too many collections in short time (Fraud) or zero collections (Slacker)
        if len(df) >= 10:  # Increased threshold for meaningful Isolation Forest
            iso = IsolationForest(contamination=0.1, random_state=42)
            df["anomaly_score"] = iso.fit_predict(X_anomaly)
            df["is_suspicious"] = df["anomaly_score"] == -1
        else:
            # Enhanced fallback for small teams: Multi-factor threshold
            df["is_suspicious"] = (
                (df["batch_events"] >= 3)
                | (df["flagged"] >= 2)
                | ((df["amount"] == 0) & (df["count"] > 0))
            )  # Flag zero collection attempts if activity exists

        # --- 2. Performance Clustering (K-Means) ---
        # Cluster into: Top Performers, Average, Underperformers
        # We use Amount and Count for this
        X_cluster = X[["amount", "count"]]

        n_clusters = 3
        if len(df) < 3:
            n_clusters = len(df)  # Edge case for very small teams

        if n_clusters > 0:
            kmeans = KMeans(n_clusters=n_clusters, random_state=42)
            df["cluster_id"] = kmeans.fit_predict(X_cluster)

            # Label Clusters based on average performance
            cluster_centers = (
                df.groupby("cluster_id")["amount"].mean().sort_values(ascending=False)
            )

            # Map ID to human label
            labels = {}
            for i, (cid, avg_amt) in enumerate(cluster_centers.items()):
                if i == 0:
                    labels[cid] = "TOP PERFORMER"
                elif i == n_clusters - 1:
                    labels[cid] = "UNDERPERFORMING"
                else:
                    labels[cid] = "STEADY"

            df["cluster_label"] = df["cluster_id"].map(labels)
        else:
            df["cluster_label"] = "N/A"

        # Return map of agent_id -> result dict
        results = {}
        # Important: risk_index was calculated in X, need to ensure it's in final iteration or access correctly
        # Let's join risk_index back to df for easier iteration
        df["risk_index"] = X["risk_index"]

        for index, row in df.iterrows():
            agent_id = row["agent_id"]
            results[agent_id] = {
                "is_suspicious": bool(row["is_suspicious"]),
                "cluster": row["cluster_label"],
                "risk_score": float(row["risk_index"]),
            }

        return results


worker_engine = WorkerIntelligence()
