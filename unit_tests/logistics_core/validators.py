"""Порт валидации из AuthService.swift (as-is, без исправлений)."""
import math
import re

_EMAIL_RE = re.compile(r"^[A-Z0-9a-z]([A-Z0-9a-z._%+-]*[A-Z0-9a-z])?@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}$")
_NAME_RE = re.compile(r"^[^\W\d_]+([-_][^\W\d_]+)?( [^\W\d_]+([-_][^\W\d_]+)?)?$")
_BAD = ".-_"


def validate_email_detailed(email: str):
    """Возвращает текст ошибки или None, если email корректен (как validateEmailDetailed)."""
    if email == "":
        return "Email енгізіңіз"
    if len(email) > 100:
        return "Email тым ұзын"
    if email[0] in _BAD:
        return "Email нүкте, дефис немесе астынғы сызықпен басталмауы керек"
    if "@" not in email:
        return "Email @ белгісін қамтуы керек"
    at = email.index("@")
    local, domain = email[:at], email[at + 1:]
    if local == "":
        return "Email @ белгісінен бұрын бөлігі болуы керек"
    if local[-1] in _BAD:
        return "Email @ белгісінен бұрын нүкте, дефис немесе астынғы сызықпен аяқталмауы керек"
    if local.count("-") > 2:
        return "Email 2 дефисден көп болмауы керек"
    if any(s in local for s in ("--", "__", "..")):
        return "Email бірінен соң бір дефис, астынғы сызық немесе нүкте болмауы керек"
    if any(s in local for s in (".-", "-.", "._", "_.", "-_", "_-")):
        return "Email дефис, астынғы сызық және нүкте бір-бірінің жанында болмауы керек"
    if domain == "":
        return "Email домен бөлігі болуы керек"
    if domain[0] in _BAD:
        return "Домен нүкте, дефис немесе астынғы сызықпен басталмауы керек"
    if domain[-1] in _BAD:
        return "Домен нүкте, дефис немесе астынғы сызықпен аяқталмауы керек"
    if "." not in domain:
        return "Доменде нүкте болуы керек"
    for seg in (s for s in domain.split(".") if s):
        if seg[0] in "-_":
            return "Домен бөліктері дефис немесе астынғы сызықпен басталмауы керек"
        if seg[-1] in "-_":
            return "Домен бөліктері дефис немесе астынғы сызықпен аяқталмауы керек"
        if "--" in seg or "__" in seg:
            return "Доменде бірінен соң бір дефис немесе астынғы сызық болмауы керек"
    if not _EMAIL_RE.match(email):
        return "Email дұрыс форматта емес"
    return None


def is_valid_password(password: str) -> bool:
    """Только латинские буквы и цифры (регэксп ^[a-zA-Z0-9]*$)."""
    return re.fullmatch(r"[a-zA-Z0-9]*", password) is not None


def is_valid_phone(phone: str) -> bool:
    """Ровно 11 цифр после удаления всех нецифровых символов (как isValidPhone)."""
    # FIX DEFECT-01: допускаем только цифры и типичные разделители (+ ( ) - пробел)
    if re.search(r"[^0-9+()\-\s]", phone):
        return False
    cleaned = re.sub(r"[^0-9]", "", phone)
    return len(cleaned) == 11


def is_valid_name(name: str) -> bool:
    return _NAME_RE.match(name) is not None and 2 <= len(name) <= 50


def is_valid_weight(text: str) -> bool:
    """isFormValid в NewOrderView: !weight.isEmpty && Double(weight) != nil."""
    if text == "":
        return False
    try:
        value = float(text)
    except ValueError:
        return False
    # FIX DEFECT-02: вес — конечное число строго больше нуля
    return math.isfinite(value) and value > 0
