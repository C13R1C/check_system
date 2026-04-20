import unittest

from app.controllers.api_controller import _extract_material_id


class ExtractMaterialIdTests(unittest.TestCase):
    def test_accepts_supported_formats(self):
        self.assertEqual(_extract_material_id("2"), 2)
        self.assertEqual(_extract_material_id("material:2"), 2)
        self.assertEqual(_extract_material_id("material_id=2"), 2)
        self.assertEqual(_extract_material_id("https://demo.local/materials/2"), 2)
        self.assertEqual(_extract_material_id("/materials/2"), 2)

    def test_rejects_invalid_or_ambiguous_formats(self):
        self.assertIsNone(_extract_material_id(""))
        self.assertIsNone(_extract_material_id("material:2:3"))
        self.assertIsNone(_extract_material_id("material_id=2x"))
        self.assertIsNone(_extract_material_id("abc"))
        self.assertIsNone(_extract_material_id("https://demo.local/materials/2/extra"))


if __name__ == "__main__":
    unittest.main()
