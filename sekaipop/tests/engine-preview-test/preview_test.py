"""Exercise the real preview Image with Qt (optional PySide6 dependency)."""
import importlib.util
import os
from pathlib import Path
import struct
import tempfile
import time
import unittest
import zlib

os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
HAS_QT = importlib.util.find_spec('PySide6') is not None
if HAS_QT:
    from PySide6.QtCore import QCoreApplication, QUrl
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQml import QQmlComponent, QQmlEngine

SOURCE = Path(__file__).resolve().parents[2] / 'modules/sekai/wallpaperSelector/WallpaperPreview.qml'


def png(path):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 2, 2, 8, 2, 0, 0, 0))
                     + chunk(b'IDAT', zlib.compress((b'\x00' + b'\xff\x00\x00' * 2) * 2)) + chunk(b'IEND', b''))


@unittest.skipUnless(HAS_QT, 'PySide6 is needed for actual QML Image tests')
class PreviewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QGuiApplication.instance() or QGuiApplication([])
        cls.engine = QQmlEngine()
        cls.component = QQmlComponent(cls.engine)
        # Observe Image.Ready without relying on a Python binding for its enum.
        source = SOURCE.read_text().replace('id: root', 'id: root\n    readonly property bool testReady: status === Image.Ready', 1)
        cls.component.setData(source.encode(), QUrl.fromLocalFile(str(SOURCE)))
        assert not cls.component.errors(), [e.toString() for e in cls.component.errors()]

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='engine # preview ')
        self.folder = Path(self.directory.name)
        png(self.folder / 'preview.png')
        self.entry = {'engine': True, 'filePath': str(self.folder), 'previewCandidates':
                      [str(self.folder / name) for name in ['preview.jpg', 'preview.jpeg', 'preview.png', 'preview.webp', 'preview.gif']]}
        self.image = self.component.createWithInitialProperties({'previewEntry': self.entry, 'asynchronous': True})
        self.assertIsNotNone(self.image)

    def tearDown(self):
        self.image.deleteLater()
        QCoreApplication.processEvents()
        self.directory.cleanup()

    def wait_for(self, predicate):
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            QCoreApplication.processEvents()
            if predicate():
                return
            time.sleep(.005)
        self.fail('Image did not reach the expected state')

    def test_missing_jpg_falls_back_to_png_in_encoded_folder(self):
        self.wait_for(lambda: self.image.property('testReady'))
        self.assertEqual(self.image.property('previewPath'), str(self.folder / 'preview.png'))
        self.assertNotEqual(self.image.property('source').toLocalFile(), str(self.folder))

    def test_delegate_reuse_drops_old_failure(self):
        # Change entries before the initial missing-JPEG failure has been processed.
        replacement = self.folder / 'next.png'
        png(replacement)
        self.image.setProperty('previewEntry', {'engine': True, 'previewCandidates': [str(replacement)]})
        self.wait_for(lambda: self.image.property('testReady'))
        self.assertEqual(self.image.property('previewIndex'), 0)
        self.assertEqual(self.image.property('previewPath'), str(replacement))

    def test_all_missing_previews_stop_without_decoding_package_folder(self):
        self.image.setProperty('previewEntry', {'engine': True, 'filePath': str(self.folder),
            'previewCandidates': [str(self.folder / 'missing.jpg'), str(self.folder / 'missing.png')]})
        self.wait_for(lambda: self.image.property('previewIndex') == 2)
        self.assertEqual(self.image.property('previewPath'), '')
        self.assertTrue(self.image.property('source').isEmpty())

    def test_plain_images_keep_normal_source(self):
        image = self.folder / 'preview.png'
        self.image.setProperty('previewEntry', {'engine': False, 'filePath': str(image)})
        self.image.setProperty('fallbackSource', QUrl.fromLocalFile(str(image)))
        self.wait_for(lambda: self.image.property('testReady'))
        self.assertEqual(self.image.property('source').toLocalFile(), str(image))


if __name__ == '__main__':
    unittest.main()
