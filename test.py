import mysql.connector
import time

conn = mysql.connector.connect(
    host="localhost",
    user="root",
    password="manager",
    database="e_commerce"
)

cursor = conn.cursor()

query = "SELECT COUNT(*) FROM userinfo WHERE name = 'John Brown' AND state_id = 1;"
nb_of_requests = 10

start_time = time.time()

for _ in range(nb_of_requests):
    cursor.execute(query)
    cursor.fetchall()

total_time = time.time() - start_time
qps = nb_of_requests / total_time

print(f"Total time: {total_time:.6f} seconds")
print(f"QPS: {qps:.2f}")

cursor.close()
conn.close()