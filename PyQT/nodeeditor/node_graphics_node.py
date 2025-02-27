from PyQt5.QtWidgets import *
from PyQt5.QtCore import *
from PyQt5.QtGui import *

# 节点的表现
class QDMGraphicsNode(QGraphicsItem):
    def __init__(self, node, title = "Node Graphics Item", parent=None):
        super().__init__(parent)

        self.node = node
        self.content = self.node.content

        self._title_color = Qt.white
        self._title_font = QFont("Consolas",10)
        self.title_height = 24
        self._brush_title = QBrush(QColor("#FF313131"))
        self._brush_background = QBrush(QColor("#E3212121"))
        self._padding = 10

        self.width = 180
        self.height = 180
        self.edge_size = 10
        self._pen_default = QPen(QColor("#7B000000"))
        self._pen_selected = QPen(QColor("#FFFFA637"))

        # 初始化标题
        self.initTitle()
        self.title = self.node.title

        # 初始化 sockets
        self.initSockets()

        # 初始化 content
        self.initContent()

        self.initUI()

    def mouseMoveEvent(self, event: 'QGraphicsSceneMouseEvent') -> None:
        super().mouseMoveEvent(event)
        self.node.updateConnectedEdges()

    def boundingRect(self):
        # 底色方框
        return QRectF(0,0, self.width, self.height).normalized()

    def initUI(self):
        self.setFlag(QGraphicsItem.ItemIsSelectable)
        self.setFlag( QGraphicsItem.ItemIsMovable)
    
    def initTitle(self):
        self.title_item = QGraphicsTextItem(self)
        self.title_item.setDefaultTextColor(self._title_color)
        self.title_item.setFont(self._title_font)
        self.title_item.setPos(self._padding, 0)
        self.title_item.setTextWidth(self.width - self._padding * 2)

    def initContent(self):
        self.grContent =QGraphicsProxyWidget(self)
        # 这个 setGeometry 有一次失效，重启电脑后正常
        self.content.setGeometry(self.edge_size, self.title_height + self.edge_size, self.width - 2* self.edge_size, self.height - 2* self.edge_size - self.title_height)
        self.grContent.setWidget(self.content)

    def initSockets(self):
        pass

    @property
    def title(self): return self._title
    @title.setter
    def title(self, value):
        self._title = value
        self.title_item.setPlainText(self._title)


    def paint(self, painter, QStyleOptionGraphicsItem, widget=None):
        # 画标题的方框
        path_title = QPainterPath()
        path_title.setFillRule(Qt.WindingFill)
        path_title.addRoundedRect(0,0,self.width, self.title_height, self.edge_size, self.edge_size)
        path_title.addRect(0,self.title_height - self.edge_size, self.edge_size, self.edge_size)
        path_title.addRect(self.width - self.edge_size, self.title_height - self.edge_size, self.edge_size, self.edge_size)
        painter.setPen(Qt.NoPen)
        painter.setBrush(self._brush_title)
        painter.drawPath(path_title.simplified())

        # 画下半部分的底色方框
        path_content = QPainterPath()
        path_content.setFillRule(Qt.WindingFill)
        path_content.addRoundedRect(0, self.title_height, self.width, self.height - self.title_height, self.edge_size, self.edge_size)
        path_content.addRect(0, self.title_height, self.edge_size, self.edge_size)
        path_content.addRect(self.width - self.edge_size, self.title_height, self.edge_size, self.edge_size)
        painter.setPen(Qt.NoPen)
        painter.setBrush(self._brush_background)
        painter.drawPath(path_content.simplified())


        # 画整个节点的外框线条
        path_outline = QPainterPath()
        path_outline.addRoundedRect(0,0,self.width, self.height, self.edge_size, self.edge_size)

        painter.setPen(self._pen_default if not self.isSelected() else self._pen_selected)
        painter.setBrush(Qt.NoBrush)
        painter.drawPath(path_outline.simplified())