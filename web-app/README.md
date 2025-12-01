# ELK  Web 

>  - 5  
>  ELK Stack 

---

##  

 Flask  Web 
-   HTTP 
-  200/404/500 
-  
-  
-  JSON  stdout

 ElasticsearchLogstashKibana 

---

##  

### 1. Web 

|  |  |  |
|---------|------|---------|
| `/` | GET |  |
| `/health` | GET |  |
| `/api/user/<user_id>` | GET |  |
| `/api/product/<product_id>` | GET |  |
| `/api/order` | GET/POST | / |
| `/api/login` | POST |  |
| `/error/404` | GET |  404  |
| `/error/500` | GET |  500  |
| `/error/timeout` | GET | 3-5 |

### 2. 

- ****JSON  Logstash 
- ****stdoutFilebeat 
- ****
  - `timestamp`: ISO 8601 
  - `level`: INFO/WARNING/ERROR
  - `http_method`: HTTP 
  - `url`:  URL
  - `status_code`: HTTP 
  - `response_time_ms`: 
  - `ip`:  IP
  - `user_agent`: 
  - `exception`: 

### 3. 

- 
- 
- 
- 

---

##  

###  Docker Compose

```bash
# 1. 
cd /home/ezhou/cloud/web-app

# 2. 
docker-compose up -d

# 3. 
docker-compose logs -f

# 4. 
curl http://localhost:5000/health

# 5. 
docker-compose down
```

###  Docker 

```bash
# 1. 
docker build -t elk-web-app .

# 2. 
docker run -d -p 5000:5000 --name elk-web-app elk-web-app

# 3. 
docker logs -f elk-web-app

# 4. 
docker stop elk-web-app
docker rm elk-web-app
```

### 

```bash
# 1. 
pip install -r requirements.txt

# 2. 
python app.py

# 3.  http://localhost:5000
```

---

##  

### 

```bash
# 1.  Web 

# 2. 
python stress_test.py
```

### 

 `stress_test.py` 

```python
# 
TARGET_URL = "http://localhost:5000"

#  10-50
CONCURRENT_USERS = 20

# - 0 
DURATION = 300  # 5 

# 
REQUEST_INTERVAL = (0.5, 2.0)

# 
VERBOSE = True
```

### 

```
 ELK 
======================================================================
: http://localhost:5000
: 20
: 300 
======================================================================

[2025-12-01 10:23:45] 200 |               |   45.32ms | http://localhost:5000/
[2025-12-01 10:23:46] 200 |           |   52.18ms | http://localhost:5000/api/user/123
[2025-12-01 10:23:47] 404 | 404           |   12.45ms | http://localhost:5000/error/404
[2025-12-01 10:23:48] 500 | 500           |   23.67ms | http://localhost:5000/error/500

 
======================================================================
: 300.00 
: 5432
: 5380 (99.0%)
: 52 (1.0%)
 QPS: 18.11

:
  200: 4123 (75.9%)
  201: 456 (8.4%)
  404: 521 (9.6%)
  500: 280 (5.2%)
  401: 52 (1.0%)

:
  : 12.34 ms
  : 5234.56 ms
  : 87.65 ms
  P50: 52.34 ms
  P95: 156.78 ms
  P99: 234.56 ms
======================================================================
```

---

##  

```
web-app/
 app.py                  # Flask Web 
 requirements.txt        # Python 
 Dockerfile             # Docker 
 docker-compose.yml     # Docker Compose 
 stress_test.py         # 
 README.md              # 
```

---

##   docker-compose.yml

 docker-compose.yml

```yaml
services:
  web-app:
    build: ./web-app
    container_name: elk-web-app
    ports:
      - "5000:5000"
    networks:
      - elk-network  # ← 
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

networks:
  elk-network:
    external: true  # ← 
```

---

##  

### 

```json
{
  "timestamp": "2025-12-01T10:23:45.123456Z",
  "level": "INFO",
  "logger": "web_app",
  "message": "Success: User 123 retrieved",
  "module": "app",
  "function": "get_user",
  "line": 145,
  "http_method": "GET",
  "url": "http://localhost:5000/api/user/123",
  "status_code": 200,
  "response_time_ms": 45.32,
  "ip": "172.17.0.1",
  "user_agent": "python-requests/2.31.0"
}
```

### 

```json
{
  "timestamp": "2025-12-01T10:23:46.789012Z",
  "level": "ERROR",
  "logger": "web_app",
  "message": "Internal Server Error",
  "module": "app",
  "function": "error_500",
  "line": 289,
  "http_method": "GET",
  "url": "http://localhost:5000/error/500",
  "status_code": 500,
  "response_time_ms": 23.67,
  "ip": "172.17.0.1",
  "user_agent": "python-requests/2.31.0",
  "exception": {
    "type": "ZeroDivisionError",
    "message": "division by zero",
    "stacktrace": [
      "Traceback (most recent call last):",
      "  File \"/app/app.py\", line 285, in error_500",
      "    result = 1 / 0",
      "ZeroDivisionError: division by zero"
    ]
  }
}
```

---

##  

### 1
-  docker-compose.yml
- 

### 2Elasticsearch
- 

### 3Logstash
-  JSON + stdout
-  Grok 
- 

### 4Kibana
- 
- 

### 6
-  README 
- 

---

##  

- **Docker**: >= 20.10
- **Docker Compose**: >= 1.29
- **Python**: >= 3.7

---

##  

### 1. 

****`Bind for 0.0.0.0:5000 failed: port is already allocated`

****
```bash
# 1
#  docker-compose.yml 
ports:
  - "5001:5000"  #  5001

# 2
sudo lsof -i :5000
sudo kill -9 <PID>
```

### 2. 

****
```bash
# 
docker logs elk-web-app

# 
docker ps -a

# 
docker-compose build --no-cache
docker-compose up -d
```

### 3. 

****
-  Web 
-  TARGET_URL 
-  Docker  IP

```bash
#  IP
docker inspect elk-web-app | grep IPAddress
```

### 4. 

****
```bash
# 
docker logs -f elk-web-app

# 
docker inspect elk-web-app | grep LogConfig
```

---

##  

1. ** Gunicorn Workers**
   ```dockerfile
   #  Dockerfile 
   CMD ["gunicorn", "--workers", "4", ...]  #  4 
   ```

2. ****
   ```yaml
   #  docker-compose.yml 
   deploy:
     resources:
       limits:
         cpus: '2.0'
         memory: 1G
   ```

3. ****

---

##  


- [ ] Web 
- [ ] 
- [ ]  stdout
- [ ]  JSON
- [ ] 
- [ ] Dockerfile 
- [ ] Docker Compose 
- [ ] 
- [ ]  1/3 
- [ ] README
