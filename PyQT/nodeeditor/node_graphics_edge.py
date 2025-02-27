import math

from PyQt5.QtWidgets import *
from PyQt5.QtGui import *
from PyQt5.QtCore import *

from node_socket import LEFT_TOP, LEFT_BOTTOM, RIGHT_BOTTOM, RIGHT_TOP

EDGE_CP_ROUNDNESS = 100

# 从属于 Edge类， 表现
class QDMGraphicsEdge(QGraphicsPathItem):
    def __init__(self, edge, parent=None):
        super().__init__(parent)

        self.edge = edge

        self._color = QColor("#001000")
        self._color_selected = QColor("#00ff00")
        self._pen = QPen(self._color)
        self._pen.setWidthF(2.0)
        self._pen_selected = QPen(self._color_selected)
        self._pen_selected.setWidthF(2.0)

        self._pen_dragging = QPen(self._color)
        self._pen_dragging.setStyle(Qt.DashLine)
        self._pen_dragging.setWidthF(2.0)

        self.setFlag(QGraphicsItem.ItemIsSelectable)
        self.setZValue(-1)  # 把连线放在节点下层

        self.posSource = [0, 0]
        self.posDestination = [200, 100]


    def setSource(self, x, y):
        self.posSource = [x,y]

    def setDestination(self, x, y):
        self.posDestination = [x,y]


    def paint(self, painter, QStyleOptionGraphicsItem, widget=None):
        self.updatePath()
        
        # raise 之后 IDE 里变灰但仍然可以执行到
        if self.edge.end_socket is None:
            painter.setPen(self._pen_dragging)  # 正在拖拽生成的边
        else:
            painter.setPen(self._pen if not self.isSelected() else self._pen_selected)
        painter.setBrush(Qt.NoBrush)
        painter.drawPath(self.path())

    def updatePath(self):
        raise NotImplemented("This should be overwritten")


class QDMGraphicsEdgeDirect(QDMGraphicsEdge):
    def updatePath(self):
        path = QPainterPath(QPointF(self.posSource[0], self.posSource[1]))
        path.lineTo(self.posDestination[0], self.posDestination[1])
        self.setPath(path)

class QDMGraphicsEdgeBezier(QDMGraphicsEdge):
    def updatePath(self):
        s = self.posSource
        d = self.posDestination
        dist = (d[0] - s[0])*0.5

        # 分别处理从左到右和从右到左
        cpx_s = +dist
        cpx_d = -dist
        cpy_s = 0
        cpy_d = 0

        if self.edge.start_socket is not None:
            sspos = self.edge.start_socket.position
            ssout = sspos in (RIGHT_TOP, RIGHT_BOTTOM)
            ssin = sspos in (LEFT_TOP, LEFT_BOTTOM)
            if (s[0] > d[0] and ssout) or (s[0] < d[0] and ssin):
                cpx_d *= -1
                cpx_s *= -1

                cpy_d = (
                    (s[1] - d[1]) / math.fabs(
                        (s[1] - d[1]) if (s[1] - d[1]) != 0 else 0.00001
                    )
                ) * EDGE_CP_ROUNDNESS
                cpy_s = (
                    (d[1] - s[1]) / math.fabs(
                        (d[1] - s[1]) if (d[1] - s[1]) != 0 else 0.00001
                    )
                ) * EDGE_CP_ROUNDNESS

        path = QPainterPath(QPointF(self.posSource[0], self.posSource[1]))
        path.cubicTo( s[0]+cpx_s, s[1]+cpy_s, d[0]+cpx_d, d[1]+cpy_d,
            self.posDestination[0], self.posDestination[1])
        self.setPath(path)
