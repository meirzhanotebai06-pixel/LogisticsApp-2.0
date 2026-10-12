"""Функции 1-2: validate_email_detailed, is_valid_phone / password / name / weight."""
import pytest
from logistics_core.validators import (is_valid_name, is_valid_password,
                                       is_valid_phone, is_valid_weight,
                                       validate_email_detailed)


# ---------- validate_email_detailed ----------
@pytest.mark.positive
@pytest.mark.parametrize("email", [
    "user@gmail.com", "a@b.kz", "first.last@mail.ru", "user+tag@example.org",
    "meirzhan-otebai@gmail.com", "x1@sub.domain.com",
])
def test_email_valid(email):
    assert validate_email_detailed(email) is None


@pytest.mark.negative
@pytest.mark.parametrize("email, fragment", [
    ("", "Email енгізіңіз"),
    ("usergmail.com", "@ белгісін"),
    ("@gmail.com", "бөлігі болуы"),
    (".user@gmail.com", "басталмауы"),
    ("user.@gmail.com", "аяқталмауы"),
    ("us..er@gmail.com", "бірінен соң бір"),
    ("a-b-c-d@gmail.com", "2 дефисден"),
    ("us.-er@gmail.com", "жанында"),
    ("user@", "домен бөлігі"),
    ("user@gmail", "нүкте болуы"),
    ("user@-gmail.com", "басталмауы"),
    ("user@gmail.c", "дұрыс форматта емес"),
    ("user@gmail.com-", "аяқталмауы"),
    ("user@mail.-gmail.com", "басталмауы"),
    ("user@gmail-.com", "аяқталмауы"),
    ("user@gm--ail.com", "бірінен соң бір"),
])
def test_email_invalid_returns_message(email, fragment):
    err = validate_email_detailed(email)
    assert err is not None and fragment in err


@pytest.mark.edge
def test_email_length_boundary():
    ok = "a" * 88 + "@gmail.com"          # ровно 98 символов
    assert validate_email_detailed(ok) is None
    border = "a" * 90 + "@gmail.com"      # ровно 100 -> ещё допустимо
    assert len(border) == 100 and validate_email_detailed(border) is None
    too_long = "a" * 91 + "@gmail.com"    # 101 -> ошибка
    assert validate_email_detailed(too_long) == "Email тым ұзын"


# ---------- password ----------
@pytest.mark.positive
@pytest.mark.parametrize("pwd", ["abc123", "Password1", "123456", "A" * 50])
def test_password_valid(pwd):
    assert is_valid_password(pwd)


@pytest.mark.negative
@pytest.mark.parametrize("pwd", ["pass word", "пароль12", "pass!word", "pa$$123", "abc-123"])
def test_password_invalid_chars(pwd):
    assert not is_valid_password(pwd)


# ---------- phone ----------
@pytest.mark.positive
@pytest.mark.parametrize("phone", ["77001234567", "+7 (700) 123-45-67", "8-700-123-45-67"])
def test_phone_valid(phone):
    assert is_valid_phone(phone)


@pytest.mark.negative
@pytest.mark.parametrize("phone", ["", "7700123456", "770012345678", "+7 700"])
def test_phone_wrong_length(phone):
    assert not is_valid_phone(phone)


@pytest.mark.negative
@pytest.mark.parametrize("phone", ["abc77001234567", "7700123456x7", "тел:77001234567"])
def test_phone_rejects_letters(phone):
    """DEFECT-01: буквы внутри номера должны делать номер некорректным."""
    assert not is_valid_phone(phone)


# ---------- name ----------
@pytest.mark.positive
@pytest.mark.parametrize("name", ["Али", "Мейіржан Өтебай", "Anna-Maria", "Jean_Luc Picard", "Ол"])
def test_name_valid(name):
    assert is_valid_name(name)


@pytest.mark.negative
@pytest.mark.parametrize("name", ["", "А", "Али1", "Али  Вали", "Али Вали Нур", "-Али", "Али-", "Али@"])
def test_name_invalid(name):
    assert not is_valid_name(name)


@pytest.mark.edge
def test_name_length_limits():
    assert not is_valid_name("а")                       # 1 символ
    assert is_valid_name("аб")                          # 2 символа — минимум
    assert is_valid_name("а" * 50)                      # 50 — максимум
    assert not is_valid_name("а" * 51)                  # 51 — превышение


# ---------- weight ----------
@pytest.mark.positive
@pytest.mark.parametrize("text", ["1", "0.5", "12.75", "1000"])
def test_weight_valid(text):
    assert is_valid_weight(text)


@pytest.mark.negative
@pytest.mark.parametrize("text", ["", "abc", "1,5kg", "--1"])
def test_weight_not_a_number(text):
    assert not is_valid_weight(text)


@pytest.mark.negative
@pytest.mark.parametrize("text", ["0", "-5", "-0.1", "nan", "inf", "-inf"])
def test_weight_must_be_positive_finite(text):
    """DEFECT-02: вес посылки должен быть конечным числом > 0."""
    assert not is_valid_weight(text)
