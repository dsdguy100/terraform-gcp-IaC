import os
import time

import mysql.connector
from google.cloud import secretmanager
from flask import Flask, render_template, request, redirect, session, url_for
from werkzeug.security import check_password_hash, generate_password_hash

app = Flask(__name__)
project_id = os.environ["GOOGLE_CLOUD_PROJECT"]
secret_client = secretmanager.SecretManagerServiceClient()


def read_secret(secret_id):
    if secret_id.startswith("projects/"):
        version_name = f"{secret_id}/versions/latest"
    else:
        version_name = f"projects/{project_id}/secrets/{secret_id}/versions/latest"
    response = secret_client.access_secret_version(request={"name": version_name})
    return response.payload.data.decode("utf-8")

app.secret_key = read_secret(os.environ["FLASK_SESSION_SECRET_ID"])


def connect_to_database():
    connection_args = {
        "host": os.environ["DB_HOST"],
        "user": os.environ["DB_USER"],
        "password": read_secret(os.environ["DB_PASSWORD_SECRET_ID"]),
        "database": os.environ["DB_NAME"],
        "connection_timeout": 10,
    }

    for attempt in range(30):
        try:
            return mysql.connector.connect(**connection_args)
        except mysql.connector.Error:
            if attempt == 29:
                raise
            time.sleep(5)


db_connection = connect_to_database()
db_cursor = db_connection.cursor()

# Create users table
db_cursor.execute("""
    CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        username VARCHAR(255) NOT NULL,
        password VARCHAR(255) NOT NULL
    )
""")

# Create user_data table
db_cursor.execute("""
    CREATE TABLE IF NOT EXISTS user_data (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        full_name VARCHAR(255),
        email VARCHAR(255),
        FOREIGN KEY (user_id) REFERENCES users(id)
    )
""")

@app.route('/')
def health_check():
    return "App is running"

@app.route('/signup', methods=['GET', 'POST'])
def signUp():
    if request.method == 'POST':
        username = request.form['username']
        password = generate_password_hash(request.form['password'])

        db_cursor.execute("INSERT INTO users (username, password) VALUES (%s, %s)", (username, password))
        db_connection.commit()
        return redirect(url_for('signin'))

    return render_template('signup.html')

@app.route('/signin', methods=['GET', 'POST'])
def signin():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']

        db_cursor.execute("SELECT id, password FROM users WHERE username = %s", (username,))
        user = db_cursor.fetchone()

        if user and check_password_hash(user[1], password):
            session['user_id'] = user[0]
            return redirect(url_for('dashboard'))

    return render_template('signin.html')

@app.route('/signout')
def signout():
    session.pop('user_id', None)
    return redirect(url_for('signin'))

@app.route('/dashboard', methods=['GET'])
def dashboard():
    if 'user_id' in session:
        user_id = session['user_id']

        db_cursor.execute("SELECT username FROM users WHERE id = %s", (user_id,))
        username = db_cursor.fetchone()[0]

        db_cursor.execute("SELECT full_name, email FROM user_data WHERE user_id = %s", (user_id,))
        profile = db_cursor.fetchone()
        full_name = profile[0] if profile else ''
        email = profile[1] if profile else ''

        db_cursor.execute("SELECT users.username, user_data.full_name, user_data.email FROM user_data JOIN users ON user_data.user_id = users.id")
        all_profiles = db_cursor.fetchall()

        return render_template('dashboard.html', username=username, full_name=full_name, email=email, all_profiles=all_profiles)
    else:
        return redirect(url_for('signin'))

@app.route('/update', methods=['POST'])
def update_user_data():
    if 'user_id' in session:
        user_id = session['user_id']
        full_name = request.form.get('full_name')
        email = request.form.get('email')

        if full_name and email:
            db_cursor.execute("SELECT * FROM user_data WHERE user_id = %s", (user_id,))
            existing = db_cursor.fetchone()

            if existing:
                db_cursor.execute("UPDATE user_data SET full_name = %s, email = %s WHERE user_id = %s",
                                  (full_name, email, user_id))
            else:
                db_cursor.execute("INSERT INTO user_data (user_id, full_name, email) VALUES (%s, %s, %s)",
                                  (user_id, full_name, email))

            db_connection.commit()

        return redirect(url_for('dashboard'))
    else:
        return redirect(url_for('signin'))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
