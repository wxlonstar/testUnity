from PyQt5.QtWidgets import *
from PyQt5.QtCore import *
from PyQt5.QtGui import *
import math

# 主窗口的 scene
class QDMGraphicsScene(QGraphicsScene):
    def __init__(self, scene:'Scene', parent = None):
        super().__init__(parent)
        
        self.scene = scene

        self.grid_size = 20
        self.grid_squares = 5
        self._color_background = QColor("#393939")
        self._color_light = QColor("#2f2f2f")
        self._color_dark = QColor("#292929")
        self._pen_light = QPen(self._color_light)
        self._pen_light.setWidth(1)
        self._pen_dark = QPen(self._color_dark)
        self._pen_dark.setWidth(2)
        self.scene_width, self.scene_height = 64000, 64000
        self.setBackgroundBrush(self._color_background)


    def setGrScene(self, width, height):
        self.setSceneRect(-width//2, -height//2, width, height)


    def drawBackground(self, painter, rect):
        super().drawBackground(painter, rect)
        
        left = int(math.floor(rect.left()))
        right = int(math.floor(rect.right()))
        top = int(math.floor(rect.top()))
        bottom = int(math.floor(rect.bottom()))
        first_left = left - (left % self.grid_size)
        first_top = top - (top % self.grid_size)
        lines_light, lines_dark = [], []
        for x in range(first_left, right, self.grid_size):
            if(x% (self.grid_size * self.grid_squares) != 0): lines_light.append(QLine(x, top, x, bottom))
            else: lines_dark.append(QLine(x,top,x,bottom))
        for y in range(first_top, bottom, self.grid_size):
            if(y% (self.grid_size * self.grid_squares) != 0): lines_light.append(QLine(left, y, right, y))
            else: lines_dark.append(QLine(left, y, right, y))
        painter.setPen(self._pen_light)
        painter.drawLines(*lines_light)
        painter.setPen(self._pen_dark)
        painter.drawLines(*lines_dark)