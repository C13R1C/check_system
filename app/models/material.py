from app.extensions import db
from app.utils.roles import ROLE_STUDENT, normalize_role
from sqlalchemy import and_, or_


ACCESS_SCOPE_CAREER = "CAREER"
ACCESS_SCOPE_GENERAL = "GENERAL"
ACCESS_SCOPE_PRIVATE = "PRIVATE"
ALLOWED_ACCESS_SCOPES = {
    ACCESS_SCOPE_CAREER,
    ACCESS_SCOPE_GENERAL,
    ACCESS_SCOPE_PRIVATE,
}


class Material(db.Model):
    __tablename__ = "materials"

    id = db.Column(db.Integer, primary_key=True)

    # Relación a laboratorio
    lab_id = db.Column(db.Integer, db.ForeignKey("labs.id"), nullable=False)
    lab = db.relationship("Lab", backref="materials")
    career_id = db.Column(db.Integer, db.ForeignKey("careers.id"), nullable=True)
    career = db.relationship("Career", backref="materials")
    access_scope = db.Column(db.String(20), nullable=False, default=ACCESS_SCOPE_CAREER, server_default=ACCESS_SCOPE_CAREER)

    # Datos base (lo que aparece en Excel)
    name = db.Column(db.Text, nullable=False)             # Equipo / Material
    category = db.Column(db.String(80), nullable=True, index=True)  # Categoría operativa
    location = db.Column(db.Text, nullable=True)          # Ubicación/Estante/Gabinete
    status = db.Column(db.Text, nullable=True)            # Estado

    # Piezas: guardamos el texto original + un número si se puede parsear
    pieces_text = db.Column(db.Text, nullable=True)        # ej: "20/20", "5", "N/A"
    pieces_qty = db.Column(db.Integer, nullable=True)            # ej: 20 (si se puede)

    # Campos que a veces vienen en Excel
    brand = db.Column(db.Text, nullable=True)
    model = db.Column(db.Text, nullable=True)
    code = db.Column(db.Text, nullable=True)              # códigos tipo "D1, D2..."
    serial = db.Column(db.Text, nullable=True)

    # Evidencia / tutorial / notas
    image_ref = db.Column(db.Text, nullable=True)         # path/URL o referencia
    image_url = db.Column(db.Text, nullable=True)
    tutorial_url = db.Column(db.Text, nullable=True)
    notes = db.Column(db.Text, nullable=True)

    # Trazabilidad (muy importante para “subir tal cual”)
    source_file = db.Column(db.Text, nullable=True)
    source_sheet = db.Column(db.Text, nullable=True)
    ####
    source_row = db.Column(db.Integer, nullable=True)

    created_at = db.Column(db.DateTime, server_default=db.func.now(), nullable=False)
    updated_at = db.Column(db.DateTime, onupdate=db.func.now(), nullable=True)

    @property
    def normalized_access_scope(self) -> str:
        scope = (self.access_scope or ACCESS_SCOPE_CAREER).strip().upper()
        return scope if scope in ALLOWED_ACCESS_SCOPES else ACCESS_SCOPE_CAREER

    @property
    def display_assignment(self) -> str:
        if self.normalized_access_scope == ACCESS_SCOPE_GENERAL:
            return "General"
        if self.normalized_access_scope == ACCESS_SCOPE_PRIVATE:
            return "Privado"
        if self.career and self.career.name:
            return f"Carrera: {self.career.name}"
        return "Carrera: Sin carrera"

    @classmethod
    def _general_visibility_expression(cls):
        from app.models.career import Career

        return or_(
            cls.access_scope == ACCESS_SCOPE_GENERAL,
            cls.career.has(db.func.upper(db.func.coalesce(Career.name, "")) == "GENERAL"),
        )

    @classmethod
    def apply_visibility_scope(cls, query, user):
        if normalize_role(getattr(user, "role", None)) != ROLE_STUDENT:
            return query
        if not getattr(user, "career_id", None):
            return query.filter(cls.id == -1)
        return query.filter(
            or_(
                cls._general_visibility_expression(),
                and_(
                    cls.access_scope == ACCESS_SCOPE_CAREER,
                    cls.career_id == user.career_id,
                ),
            )
        )

    @classmethod
    def apply_career_filter(cls, query, career_id: int | None):
        if not career_id:
            return query
        return query.filter(
            and_(
                cls.access_scope == ACCESS_SCOPE_CAREER,
                cls.career_id == career_id,
            )
        )

    @classmethod
    def user_can_access(cls, material: "Material | None", user) -> bool:
        if material is None:
            return False
        if normalize_role(getattr(user, "role", None)) != ROLE_STUDENT:
            return True
        if material.normalized_access_scope == ACCESS_SCOPE_GENERAL:
            return True
        if material.career and (material.career.name or "").strip().upper() == "GENERAL":
            return True
        if material.normalized_access_scope == ACCESS_SCOPE_CAREER:
            user_career_id = getattr(user, "career_id", None)
            return bool(user_career_id) and material.career_id == user_career_id
        return False

    def __repr__(self) -> str:
        return f"<Material {self.id} {self.name}>"
