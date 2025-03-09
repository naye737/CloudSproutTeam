import logging
import os
import pymysql
import re  # ✅ 정규식 모듈을 반드시 추가
import json  # ✅ json 모듈 추가
import time
from flask import Flask, request, jsonify, Response
from flask_cors import CORS  # CORS 추가
from urllib.parse import unquote
from logging.handlers import RotatingFileHandler

app = Flask(__name__)
CORS(app, resources={r"/api/*": {"origins": "*"}})  # 모든 API 요청 허용

# ✅ 로그 설정
log_formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')

# ✅ 로그 파일 핸들러 추가
LOG_DIR = "/var/log/"
log_file = os.path.join(LOG_DIR, "flask.log")
file_handler = RotatingFileHandler(log_file, maxBytes=10 * 1024 * 1024, backupCount=3)
file_handler.setFormatter(log_formatter)
file_handler.setLevel(logging.INFO)

# ✅ 콘솔 로그도 함께 출력되도록 설정
console_handler = logging.StreamHandler()
console_handler.setFormatter(log_formatter)
console_handler.setLevel(logging.INFO)

# ✅ Flask 앱에 로그 핸들러 추가
app.logger.addHandler(file_handler)
app.logger.addHandler(console_handler)
app.logger.setLevel(logging.INFO)

app.logger.info("🚀 Flask 로그 설정 완료!")

def wait_for_db():
    """ RDS가 활성화될 때까지 대기 """
    retries = 10
    for i in range(retries):
        try:
            connection = pymysql.connect(**db_config)
            app.logger.info("✅ MySQL 연결 성공!")
            connection.close()
            return True
        except pymysql.MySQLError as e:
            app.logger.warning(f"⏳ MySQL 연결 대기 중 ({i+1}/{retries})... 오류: {str(e)}")
            time.sleep(10)
    app.logger.error("❌ MySQL 연결 실패: 데이터베이스가 활성화되지 않음.")
    return False

# ✅ MySQL 연결 정보 (기존과 동일)
db_config = {
    'host': 'aurora-multi-master-cluster.cluster-cpyewiyugsry.ap-northeast-2.rds.amazonaws.com',
    'port': 3306,
    'user': 'cloudee',
    'password': 'jehj240424!',
    'database': 'concert',  # ✅ 명확하게 사용할 데이터베이스 지정
    'cursorclass': pymysql.cursors.DictCursor,
    'charset': 'utf8mb4',
    'use_unicode': True
}

# ✅ MySQL 연결 함수 (기존과 동일)
def get_db_connection():
    try:
        app.logger.info(f"🔍 MySQL 연결 시도: {db_config['host']}:{db_config['port']}, 사용자: {db_config['user']}")
        connection = pymysql.connect(**db_config)
        app.logger.info("✅ MySQL 연결 성공!")
        return connection
    except pymysql.MySQLError as e:
        app.logger.error(f"❌ MySQL 연결 실패: {str(e)}")
        return None

# ✅ 테이블 자동 생성 (concert 데이터베이스를 명시적으로 선택)
def create_table():
    connection = get_db_connection()
    if connection:
        try:
            cursor = connection.cursor()

            create_table_sql = """
            CREATE TABLE IF NOT EXISTS tickets (
                id INT AUTO_INCREMENT PRIMARY KEY,
                name VARCHAR(100) NOT NULL,
                phone VARCHAR(20) NOT NULL,
                seat VARCHAR(10) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            """
            cursor.execute(create_table_sql)
            connection.commit()
            cursor.close()
            app.logger.info("✅ 테이블 생성 완료! (tickets)")
        except Exception as e:
            app.logger.error(f"❌ 테이블 생성 실패: {str(e)}")
        finally:
            connection.close()


# ✅ 애플리케이션 실행 시 자동으로 테이블 생성
create_table()


# ✅ Health Check 엔드포인트
@app.route("/healthz", methods=["GET"])
def health_check():
    return jsonify({"status": "healthy"}), 200

# ✅ 기본 홈 엔드포인트
@app.route("/")
def home():
    return jsonify({"message": "Flask is running!"}), 200

# ✅ 예약된 좌석 목록 조회 API
@app.route('/api/tickets/booked', methods=['GET'])
def get_booked_seats():
    connection = get_db_connection()
    if not connection:
        return jsonify({"message": "데이터베이스 연결 실패"}), 500

    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT seat FROM tickets")  # ✅ "concert.tickets" → "tickets"
            booked_seats = [row["seat"] for row in cursor.fetchall()]
            return jsonify(booked_seats), 200
    except Exception as e:
        app.logger.error(f"❌ 예약된 좌석 조회 실패: {str(e)}")
        return jsonify({"message": "예약된 좌석을 불러오는 중 오류 발생"}), 500
    finally:
        connection.close()

# ✅ 좌석 예약 API
@app.route('/api/tickets/reserve', methods=['POST', 'OPTIONS'])
def reserve_tickets():
    if request.method == "OPTIONS":
        return jsonify({"message": "Preflight request ok"}), 200

    data = request.json
    name = data.get('name', '').strip()
    phone = data.get('phone', '').strip()
    seats = data.get('seats', [])

    if not name or not phone or not seats:
        return jsonify({"message": "이름, 전화번호 및 좌석을 입력하세요."}), 400

    if len(name) > 10 or not re.match(r"^[ㄱ-ㅎ가-힣a-zA-Z]+$", name):
        return jsonify({"message": "이름은 한글/영어만 가능하며 최대 10자까지 입력 가능합니다."}), 400
    if len(phone) > 11 or not phone.isdigit():
        return jsonify({"message": "전화번호는 숫자만 가능하며 최대 11자까지 입력 가능합니다."}), 400

    connection = get_db_connection()
    if not connection:
        return jsonify({"message": "데이터베이스 연결 실패"}), 500

    try:
        with connection.cursor() as cursor:
            format_strings = ','.join(['%s'] * len(seats))
            cursor.execute(f"SELECT seat FROM tickets WHERE seat IN ({format_strings})", seats)  # ✅ "concert.tickets" → "tickets"
            booked_seats = [row["seat"] for row in cursor.fetchall()]

            if booked_seats:
                return jsonify({"message": "이미 예약된 좌석 포함", "booked_seats": booked_seats}), 400

            query = "INSERT INTO tickets (name, phone, seat) VALUES (%s, %s, %s)"  # ✅ "concert.tickets" → "tickets"
            for seat in seats:
                if not re.match(r"^[A-Za-z0-9]+$", seat):
                    return jsonify({"message": f"잘못된 좌석 번호: {seat}"}), 400
                cursor.execute(query, (name, phone, seat))

            connection.commit()
            app.logger.info(f"✅ 예매 성공: {name}, {phone}, {seats}")
            return jsonify({"message": "예매 성공!", "reserved_seats": seats}), 200

    except pymysql.MySQLError as db_error:
        app.logger.error(f"❌ MySQL 예매 실패: {str(db_error)}")
        return jsonify({"message": "데이터베이스 오류 발생"}), 500
    finally:
        connection.close()


# ✅ 예매 내역 조회 API
@app.route('/api/tickets/check', methods=['GET'])
def check_booking():
    try:
        raw_name = request.args.get('name', '').strip()
        phone = request.args.get('phone', '').strip()

        name = unquote(unquote(raw_name))
        app.logger.info(f"🔍 [API 요청] 받은 이름(name): '{name}', 전화번호(phone): '{phone}'")

        if not name or not phone:
            return jsonify({"message": "이름과 전화번호를 입력하세요."}), 400

        connection = get_db_connection()
        if not connection:
            return jsonify({"message": "데이터베이스 연결 실패"}), 500

        try:
            with connection.cursor() as cursor:
                query = "SELECT seat FROM tickets WHERE BINARY name = %s AND phone = %s"  # ✅ "concert.tickets" → "tickets"
                cursor.execute(query, (name, phone))
                seats = [row["seat"] for row in cursor.fetchall()]

                if seats:
                    app.logger.info(f"✅ 예매 확인 성공: {seats}")
                    return jsonify({
                        "message": "예매 확인 성공",
                        "name": name,
                        "phone": phone,
                        "seats": seats,
                        "date": "2025년 5월 10일 저녁 7시",
                        "location": "고척 스카이돔"
                    }), 200
                else:
                    app.logger.info(f"❌ 예매 내역 없음: name={name}, phone={phone}")
                    return jsonify({"message": "예매 내역이 없습니다."}), 404

        except Exception as db_error:
            app.logger.error(f"❌ 데이터 조회 실패: {str(db_error)}")
            return jsonify({"message": "예매 내역 조회 중 오류 발생"}), 500
        finally:
            connection.close()

    except Exception as e:
        app.logger.error(f"❌ API 처리 중 오류 발생: {str(e)}")
        return jsonify({"message": "서버 내부 오류 발생"}), 500

@app.after_request
def add_cors_headers(response):
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    return response

# ✅ Flask 실행
if __name__ == "__main__":
    app.logger.info("🚀 Flask 서버 시작 중...")

    if wait_for_db():
        create_table()  # ✅ RDS 연결 확인 후 테이블 생성
        app.run(host="0.0.0.0", port=5000, debug=False)
    else:
        app.logger.error("🔥 서버 종료: MySQL 연결 불가")