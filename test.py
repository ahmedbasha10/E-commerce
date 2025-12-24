import mysql.connector
import time
import uuid

# ================= CONFIG =================
HOST = "localhost"
USER = "root"
PASSWORD = "manager"
DB = "e_commerce"

NB_REQUESTS = 10        # for SELECT
NB_INSERTS = 1000000     # for INSERT

TEST_TYPE = "insert"    # "select" or "insert"
# ==========================================


def run_select_test(cursor):
    query = """
        SELECT COUNT(*)
        FROM userinfo
        WHERE name = 'John Brown' AND state_id = 1;
    """

    start_time = time.time()

    for _ in range(NB_REQUESTS):
        cursor.execute(query)
        cursor.fetchall()

    total_time = time.time() - start_time
    qps = NB_REQUESTS / total_time

    print("=== SELECT TEST ===")
    print(f"Total time: {total_time:.6f} seconds")
    print(f"QPS: {qps:.2f}")


def run_insert_test(cursor, conn):
    query = """
        INSERT INTO userinfoauto
        (name, email, password, dob, address, city, state_id, zip, country_id, account_type, closest_airport)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """

    uuid_query = """
        INSERT INTO userinfouuid
        (uuid, name, email, password, dob, address, city, state_id, zip, country_id, account_type, closest_airport)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """

    base_params = (
        "John Smith",
        "john.smith@email.com",
        "1234",
        "1986-02-14",
        "1795 Santiago de Compostela Way",
        "Austin",
        1,
        "18743",
        1,
        "customer account",
        "aus"
    )

    start_time = time.time()

    for i in range(NB_INSERTS):
        params = (
            str(uuid.uuid4()),
            base_params[0],
            f"john.smith{i}@email.com",  # unique email
            *base_params[2:]
        )
        cursor.execute(uuid_query, params)

    conn.commit()

    total_time = time.time() - start_time

    print("=== INSERT TEST ===")
    print(f"Total time: {total_time:.6f} seconds")


def main():
    conn = mysql.connector.connect(
        host=HOST,
        user=USER,
        password=PASSWORD,
        database=DB
    )
    cursor = conn.cursor()

    if TEST_TYPE == "select":
        run_select_test(cursor)
    elif TEST_TYPE == "insert":
        run_insert_test(cursor, conn)
    else:
        print("Invalid TEST_TYPE. Use 'select' or 'insert'.")

    cursor.close()
    conn.close()


if __name__ == "__main__":
    main()
