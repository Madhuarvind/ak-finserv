import pandas as pd
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler


class BehaviorEngine:
    def __init__(self):
        self.scaler = StandardScaler()
        # For small datasets, we retrain on the fly to adapt to changing behavior immediately.
        # For larger datasets, we would load a saved model.

    def analyze_behavior(self, customer_features):
        """
        Input: dataframe or list of dicts with:
        - reliability_score (0-100)
        - avg_delay_days (float)
        - max_delay_days (float)
        - total_loans_closed (int)
        - payment_volatility (std dev of payment intervals)

        Output: Dictionary mapping customer_id -> Segment & Suggested Limit
        """
        if not customer_features:
            return {}

        df = pd.DataFrame(customer_features)
        if df.empty:
            return {}

        # Features for clustering
        # We focus on reliability and consistency
        X = df[["reliability_score", "avg_delay_days", "payment_volatility"]].fillna(0)

        # Scaling
        X_scaled = self.scaler.fit_transform(X)

        # K-Means Clustering (4 Segments: VIP, Regular, Inconsistent, Risk)
        n_clusters = 4
        if len(df) < 4:
            n_clusters = len(df)

        if n_clusters > 1:  # Require at least 2 points for clustering
            kmeans = KMeans(n_clusters=n_clusters, random_state=42)
            df["cluster"] = kmeans.fit_predict(X_scaled)

            # Rank clusters by Reliability (Highest score = Best)
            cluster_rank = (
                df.groupby("cluster")["reliability_score"]
                .mean()
                .sort_values(ascending=False)
            )

            # Assign Labels
            labels = {}
            for i, (cid, score) in enumerate(cluster_rank.items()):
                if i == 0:
                    labels[cid] = "VIP (GOLD)"
                elif i == 1:
                    labels[cid] = "SILVER"
                elif i == 2:
                    labels[cid] = "BRONZE"
                else:
                    labels[cid] = "HIGH RISK"

            df["segment"] = df["cluster"].map(labels)
        else:
            # Fallback for single customer or cold start
            rel_score = df.iloc[0]["reliability_score"] if not df.empty else 0
            if rel_score >= 90:
                df["segment"] = "VIP (GOLD)"
            elif rel_score >= 70:
                df["segment"] = "SILVER"
            elif rel_score >= 40:
                df["segment"] = "BRONZE"
            else:
                df["segment"] = "HIGH RISK"

        results = {}
        for index, row in df.iterrows():
            cid = row["customer_id"]
            segment = row["segment"]

            # AI Loan Suggestion Rule
            # Base logic tailored by Segment
            base_capacity = float(row.get("avg_payment_capacity", 5000))
            multiplier = 1.0

            if segment == "VIP (GOLD)":
                multiplier = 2.5  # Trust them with more
            elif segment == "SILVER":
                multiplier = 1.5
            elif segment == "HIGH RISK":
                multiplier = 0.5  # Restrict them

            suggested_limit = base_capacity * 10 * multiplier
            suggested_limit = (
                round(suggested_limit / 5000) * 5000
            )  # Round to nearest 5k
            suggested_limit = max(
                min(suggested_limit, 200000), 10000
            )  # Cap between 10k and 2lakh

            results[cid] = {"segment": segment, "suggested_limit": suggested_limit}

        return results


behavior_engine = BehaviorEngine()
