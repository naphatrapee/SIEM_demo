"""Alert rule evaluation (every 30s) + retention (daily)."""
import time


def main():
    print("worker started", flush=True)
    while True:
        # TODO: run rules (GROUP BY src_ip HAVING count(*) >= threshold), insert alerts, POST webhook
        # TODO: once a day: SELECT ensure_partition(current_date+1); SELECT drop_old_partitions(7);
        time.sleep(30)


if __name__ == "__main__":
    main()
