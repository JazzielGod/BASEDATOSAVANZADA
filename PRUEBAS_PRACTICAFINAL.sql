create database SCGP;
use SCGP;

CREATE TABLE TIPO_INFRACCION (
  ID_INFRACCION INT PRIMARY KEY AUTO_INCREMENT,
  DESCRIPCION VARCHAR(100),
  PUNTOS INT CHECK(PUNTOS >= 0),
  COSTO FLOAT CHECK(COSTO >= 0)
);

delimiter $$
CREATE PROCEDURE ALTA_TIPO_INFRACCION (
  IN p_DESCRIPCION VARCHAR(100),
  IN p_PUNTOS INT,
  IN p_COSTO FLOAT
)
BEGIN
  INSERT INTO TIPO_INFRACCION (DESCRIPCION, PUNTOS, COSTO)
  VALUES (p_DESCRIPCION, p_PUNTOS, p_COSTO);
END $$
delimiter ;
CALL ALTA_TIPO_INFRACCION('No usar cinturón de seguridad', 1, 497);
CALL ALTA_TIPO_INFRACCION('Estacionarse en rojo', 2, 2264);
CALL ALTA_TIPO_INFRACCION('Exceso de velocidad', 3, 1500);
CALL ALTA_TIPO_INFRACCION('No respetar la luz roja del semáforo', 3, 755);
CALL ALTA_TIPO_INFRACCION('Vuelta prohibida', 3, 2264);
CALL ALTA_TIPO_INFRACCION('Estacionarse en lugares para discapacitados', 3, 2150);
CALL ALTA_TIPO_INFRACCION('Uso del celular', 3, 2642);
CALL ALTA_TIPO_INFRACCION('Circular en sentido contrario', 3, 3200);
CALL ALTA_TIPO_INFRACCION('Manejar en estado de ebriedad', 6, 6640);
CALL ALTA_TIPO_INFRACCION('Invasión de pasos peatonales', 3, 2100);

CREATE TABLE MULTAS (
  ID_MULTA INT PRIMARY KEY AUTO_INCREMENT,
  FECHA DATE NOT NULL,
  PLACAS_VEHICULO VARCHAR(10),
  ID_INFRACCION INT,
  FOREIGN KEY (ID_INFRACCION) REFERENCES TIPO_INFRACCION (ID_INFRACCION)
);

CREATE TABLE HISTORIAL_INFRACCIONES (
  ID_HISTORIAL INT PRIMARY KEY AUTO_INCREMENT,
  PLACAS_VEHICULO VARCHAR(10) UNIQUE,
  PUNTOS_TOTALES INT CHECK (PUNTOS_TOTALES >= 0),
  DEUDA FLOAT CHECK (DEUDA >= 0)
);

delimiter $$
CREATE PROCEDURE LEVANTAR_MULTA(IN placas_vehiculo VARCHAR(10), IN id_infraccion INT)
BEGIN
  INSERT INTO MULTAS (FECHA, PLACAS_VEHICULO, ID_INFRACCION)
  VALUES (CURDATE(), placas_vehiculo, id_infraccion);
END $$
delimiter ;
CALL LEVANTAR_MULTA('ABC1234', 1);
-- Inserción de multas
CALL LEVANTAR_MULTA('ABC123', 1);
CALL LEVANTAR_MULTA('DEF456', 2);
CALL LEVANTAR_MULTA('ABC123', 3);
CALL LEVANTAR_MULTA('GHI789', 5);
CALL LEVANTAR_MULTA('JKL012', 10);

select * from multas;
select * from historial_infracciones;
select * from tipo_infraccion;
SELECT PUNTOS_TOTALES FROM HISTORIAL_INFRACCIONES;

delimiter $$
CREATE TRIGGER multas_trigger AFTER INSERT ON MULTAS FOR EACH ROW
BEGIN
  DECLARE puntos_aux INT;
  DECLARE deuda_aux FLOAT;
  SELECT PUNTOS, COSTO INTO puntos_aux, deuda_aux FROM TIPO_INFRACCION WHERE ID_INFRACCION = NEW.ID_INFRACCION;
  IF EXISTS (SELECT * FROM HISTORIAL_INFRACCIONES WHERE PLACAS_VEHICULO = NEW.PLACAS_VEHICULO) THEN
    UPDATE HISTORIAL_INFRACCIONES
    SET PUNTOS_TOTALES = PUNTOS_TOTALES + puntos_aux,
        DEUDA = DEUDA + deuda_aux
    WHERE PLACAS_VEHICULO = NEW.PLACAS_VEHICULO;
  ELSE
    INSERT INTO HISTORIAL_INFRACCIONES (PLACAS_VEHICULO, PUNTOS_TOTALES, DEUDA)
    VALUES (NEW.PLACAS_VEHICULO, puntos_aux, deuda_aux);
  END IF;
END $$
delimiter ;

delimiter $$
CREATE PROCEDURE PAGAR_MULTA(
  IN placa_vehiculo VARCHAR(10),
  IN pago FLOAT
)
BEGIN
  DECLARE deuda_actual FLOAT;
  SELECT DEUDA INTO deuda_actual FROM HISTORIAL_INFRACCIONES WHERE PLACAS_VEHICULO = placa_vehiculo;
  
  IF pago > deuda_actual THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El pago no puede ser mayor a la deuda actual';
  ELSEIF pago < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El pago no puede ser menor a cero';
  ELSE
    SET deuda_actual = deuda_actual - pago;
    UPDATE HISTORIAL_INFRACCIONES SET DEUDA = deuda_actual WHERE PLACAS_VEHICULO = placa_vehiculo;
  END IF;
END $$
delimiter ;
-- Pago exacto
CALL PAGAR_MULTA('ABC123', 2006);
SELECT * FROM HISTORIAL_INFRACCIONES WHERE PLACAS_VEHICULO = 'ABC123';

-- Pago menor a la deuda
CALL PAGAR_MULTA('DEF456', 1000);
SELECT * FROM HISTORIAL_INFRACCIONES WHERE PLACAS_VEHICULO = 'DEF456';

-- Pago mayor a la deuda
CALL PAGAR_MULTA('GHI789', 3000);
SELECT * FROM HISTORIAL_INFRACCIONES WHERE PLACAS_VEHICULO = 'GHI789';

delimiter %%
CREATE FUNCTION ESTADO_DE_PUNTOS(puntos_totales INT)
RETURNS VARCHAR(20)
reads sql data
BEGIN
  DECLARE estado VARCHAR(20);
  
  IF puntos_totales <= 3 THEN
    SET estado = 'ESTABLE';
  ELSEIF puntos_totales <= 6 THEN
    SET estado = 'ADVERTIDO';
  ELSEIF puntos_totales <= 11 THEN
    SET estado = 'PELIGRO';
  ELSE
    SET estado = 'LICENCIA CANCELADA';
  END IF;

  RETURN estado;
END %%
delimiter ;
SELECT ESTADO_DE_PUNTOS(1); -- Devuelve 'ESTABLE'
SELECT ESTADO_DE_PUNTOS(4); -- Devuelve 'ADVERTIDO'
SELECT ESTADO_DE_PUNTOS(9); -- Devuelve 'PELIGRO'
SELECT ESTADO_DE_PUNTOS(12); -- Devuelve 'LICENCIA CANCELADA'
