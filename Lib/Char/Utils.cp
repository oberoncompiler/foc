MODULE CharUtils;

PROCEDURE IsUpper*(c: CHAR): BOOLEAN;
BEGIN
  RETURN
    ('A' <= c) & (c  <= 'Z') (* Латиница *)
    OR
    ('А' <= c) & (c <= 'Я') OR (c = 'Ё'); (* Кириллица *)
END IsUpper;

PROCEDURE IsLower*(c: CHAR): BOOLEAN;
BEGIN
  RETURN
    ('a' <= c) & (c <= 'z') (* Латиница *)
    OR
    ('а' <= c) & (c <= 'я') OR (c = 'ё'); (* Кириллица *)
END IsLower;

END CharUtils.
