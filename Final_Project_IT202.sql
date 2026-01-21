

DROP DATABASE IF EXISTS insurance_management;
CREATE DATABASE insurance_management;
USE insurance_management;

-- TABLE: Customers

CREATE TABLE Customers (
    customer_id VARCHAR(10) PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(15) UNIQUE NOT NULL,
    email VARCHAR(100),
    join_date DATE DEFAULT (CURRENT_DATE)
);


-- TABLE: Insurance_Packages

CREATE TABLE Insurance_Packages (
    package_id VARCHAR(10) PRIMARY KEY,
    package_name VARCHAR(100) NOT NULL,
    max_limit DECIMAL(15,0) NOT NULL CHECK (max_limit > 0),
    base_premium DECIMAL(15,0) NOT NULL
);


CREATE TABLE Policies (
    policy_id VARCHAR(10) PRIMARY KEY,
    customer_id VARCHAR(10),
    package_id VARCHAR(10),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status VARCHAR(20) CHECK (status IN ('Active','Expired','Cancelled')),
    CONSTRAINT fk_policy_customer FOREIGN KEY (customer_id) REFERENCES Customers(customer_id),
    CONSTRAINT fk_policy_package FOREIGN KEY (package_id) REFERENCES Insurance_Packages(package_id)
);


CREATE TABLE Claims (
    claim_id VARCHAR(10) PRIMARY KEY,
    policy_id VARCHAR(10),
    claim_date DATE NOT NULL,
    claim_amount DECIMAL(15,0) NOT NULL CHECK (claim_amount > 0),
    status VARCHAR(20) CHECK (status IN ('Pending','Approved','Rejected')),
    CONSTRAINT fk_claim_policy FOREIGN KEY (policy_id) REFERENCES Policies(policy_id)
);


CREATE TABLE Claim_Processing_Log (
    log_id VARCHAR(10) PRIMARY KEY,
    claim_id VARCHAR(10),
    action_detail VARCHAR(255),
    recorded_at DATETIME,
    processor VARCHAR(50),
    CONSTRAINT fk_log_claim FOREIGN KEY (claim_id) REFERENCES Claims(claim_id)
);



INSERT INTO Customers VALUES
('C001','Nguyen Hoang Long','0901112223','long.nh@gmail.com','2024-01-15'),
('C002','Tran Thi Kim Anh','0988877766','anh.tk@yahoo.com','2024-03-10'),
('C003','Le Hoang Nam','0903334445','nam.lh@outlook.com','2025-05-20'),
('C004','Pham Minh Duc','0355556667','duc.pm@gmail.com','2025-08-12'),
('C005','Hoang Thu Thao','0779998881','thao.ht@gmail.com','2026-01-01');

INSERT INTO Insurance_Packages VALUES
('PKG01','Bảo hiểm Sức khỏe Gold',500000000,5000000),
('PKG02','Bảo hiểm Ô tô Liberty',1000000000,15000000),
('PKG03','Bảo hiểm Nhân thọ An Bình',2000000000,25000000),
('PKG04','Bảo hiểm Du lịch Quốc tế',100000000,1000000),
('PKG05','Bảo hiểm Tai nạn 24/7',200000000,2500000);

INSERT INTO Policies VALUES
('POL101','C001','PKG01','2024-01-15','2025-01-15','Expired'),
('POL102','C002','PKG02','2024-03-10','2026-03-10','Active'),
('POL103','C003','PKG03','2025-05-20','2035-05-20','Active'),
('POL104','C004','PKG04','2025-08-12','2025-09-12','Expired'),
('POL105','C005','PKG01','2026-01-01','2027-01-01','Active');

INSERT INTO Claims VALUES
('CLM901','POL102','2024-06-15',12000000,'Approved'),
('CLM902','POL103','2025-10-20',50000000,'Pending'),
('CLM903','POL101','2024-11-05',5500000,'Approved'),
('CLM904','POL105','2026-01-15',2000000,'Rejected'),
('CLM905','POL102','2025-02-10',120000000,'Approved');

INSERT INTO Claim_Processing_Log VALUES
('L001','CLM901','Đã nhận hồ sơ hiện trường','2024-06-15 09:00','Admin_01'),
('L002','CLM901','Chấp nhận bồi thường xe tai nạn','2024-06-20 14:30','Admin_01'),
('L003','CLM902','Đang thẩm định hồ sơ bệnh án','2025-10-21 10:00','Admin_02'),
('L004','CLM904','Từ chối do lỗi cố ý của khách hàng','2026-01-16 16:00','Admin_03'),
('L005','CLM905','Đã thanh toán qua chuyển khoản','2025-02-15 08:30','Accountant_01');



-- Increase base premium 15% for packages with max_limit > 500,000,000
UPDATE Insurance_Packages
SET base_premium = base_premium * 1.15
WHERE max_limit > 500000000;

-- Delete logs before 2025-06-20
DELETE FROM Claim_Processing_Log
WHERE recorded_at < '2025-06-20';



-- Q1
SELECT * FROM Policies
WHERE status = 'Active' AND YEAR(end_date) = 2026;

-- Q2
SELECT full_name, email FROM Customers
WHERE full_name LIKE '%Hoang%' AND YEAR(join_date) >= 2025;

-- Q3
SELECT * FROM Claims
ORDER BY claim_amount DESC
LIMIT 3 OFFSET 1;





-- Q1
SELECT c.full_name, pck.package_name, p.start_date, cl.claim_amount
FROM Policies p
JOIN Customers c ON p.customer_id = c.customer_id
JOIN Insurance_Packages pck ON p.package_id = pck.package_id
LEFT JOIN Claims cl ON p.policy_id = cl.policy_id;

-- Q2
SELECT c.full_name, SUM(cl.claim_amount) AS total_paid
FROM Customers c
JOIN Policies p ON c.customer_id = p.customer_id
JOIN Claims cl ON p.policy_id = cl.policy_id
WHERE cl.status = 'Approved'
GROUP BY c.customer_id
HAVING total_paid > 50000000;

-- Q3
SELECT package_id, COUNT(*) AS total_customers
FROM Policies
GROUP BY package_id
ORDER BY total_customers DESC
LIMIT 1;



CREATE INDEX idx_policy_status_date ON Policies(status, start_date);

CREATE VIEW vw_customer_summary AS
SELECT 
    c.full_name,
    COUNT(p.policy_id) AS total_policies,
    SUM(ip.base_premium) AS total_premium
FROM Customers c
LEFT JOIN Policies p ON c.customer_id = p.customer_id
LEFT JOIN Insurance_Packages ip ON p.package_id = ip.package_id
GROUP BY c.customer_id;



DELIMITER $$

CREATE TRIGGER trg_after_claim_approved
AFTER UPDATE ON Claims
FOR EACH ROW
BEGIN
    IF NEW.status = 'Approved' AND OLD.status <> 'Approved' THEN
        INSERT INTO Claim_Processing_Log
        VALUES (UUID(), NEW.claim_id, 'Payment processed to customer', NOW(), 'System');
    END IF;
END$$

CREATE TRIGGER trg_prevent_delete_active_policy
BEFORE DELETE ON Policies
FOR EACH ROW
BEGIN
    IF OLD.status = 'Active' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot delete active policy';
    END IF;
END$$

DELIMITER ;



DELIMITER $$

CREATE PROCEDURE sp_check_claim_limit(
    IN p_claim_id VARCHAR(10),
    OUT message VARCHAR(20)
)
BEGIN
    DECLARE claim_amt DECIMAL(15,0);
    DECLARE max_amt DECIMAL(15,0);

    SELECT c.claim_amount, ip.max_limit
    INTO claim_amt, max_amt
    FROM Claims c
    JOIN Policies p ON c.policy_id = p.policy_id
    JOIN Insurance_Packages ip ON p.package_id = ip.package_id
    WHERE c.claim_id = p_claim_id;

    IF claim_amt > max_amt THEN
        SET message = 'Exceeded';
    ELSE
        SET message = 'Valid';
    END IF;
END$$


