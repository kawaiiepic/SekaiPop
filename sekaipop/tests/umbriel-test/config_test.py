import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[2] / 'scripts/umbriel/config.py'
spec = importlib.util.spec_from_file_location('umbriel_config', SCRIPT)
config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config)


class ConfigTests(unittest.TestCase):
    def test_includes_and_parent_precedence(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'keys.toml').write_text('[keybinds]\n"Mod+A"="spawn old"\n"Mod+B"={action="window-close"}\n')
            (root / 'config.toml').write_text('[include]\nfiles=["keys.toml"]\n[include.optional]\nfiles=["missing.toml"]\n[general]\nmod_key="Alt"\n[keybinds]\n"Mod+A"="spawn kitty"\n"Mod"="overview-toggle"\n')
            parsed = config.read_config(root / 'config.toml')
            binds = config.bindings(parsed)
            self.assertEqual(binds[0]['arg'], 'kitty')
            self.assertEqual(binds[0]['modmask'], 8)
            self.assertEqual(binds[1]['dispatcher'], 'window-close')
            self.assertEqual(binds[2]['key'], 'Alt_L')
            self.assertTrue(binds[2]['release'])

    def test_cycle_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'a.toml').write_text('[include]\nfiles=["b.toml"]\n')
            (root / 'b.toml').write_text('[include]\nfiles=["a.toml"]\n')
            with self.assertRaisesRegex(ValueError, 'include cycle'):
                config.read_config(root / 'a.toml')

    def test_missing_required_include_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'config.toml'
            path.write_text('[include]\nfiles=["missing.toml"]\n')
            with self.assertRaises(FileNotFoundError):
                config.read_config(path)

    def test_custom_path(self):
        with patch.dict(os.environ, {'UMBRIEL_CONFIG': '/custom/umbriel.toml'}):
            self.assertEqual(str(config.config_path()), '/custom/umbriel.toml')


if __name__ == '__main__':
    unittest.main()
