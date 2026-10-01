import mysql.connector
import boto3
from flask import Flask, render_template, request, redirect, session, url_for

app = Flask(__name__)
app.secret_key = "your_secret_key"  # Replace with a secure key

# Retrieve MySQL password from AWS SSM
ssm = boto3.client('ssm', region_name='us-east-1')
parameter_name = "mysql_psw"
response = ssm.get_parameter(Name=parameter_name, WithDecryption=True)
mysql_password = response['Parameter']['Value']

# Connect to MySQL
db_connection = mysql.connector.connect(
    host="database_endpoint",  # Replace with your DB endpoint
    user="admin",
    password=mysql_password,
    database="test"
)
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
        password = request.form['password']

        db_cursor.execute("INSERT INTO users (username, password) VALUES (%s, %s)", (username, password))
        db_connection.commit()
        return redirect(url_for('signin'))

    return render_template('signup.html')

@app.route('/signin', methods=['GET', 'POST'])
def signin():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']

        db_cursor.execute("SELECT * FROM users WHERE username = %s AND password = %s", (username, password))
        user = db_cursor.fetchone()

        if user:
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
