# XLPickerNode

## Overview
XLPikcer node is a SKNode that works like UIPickerView. It provides you with reuse features like UIPickerView for optimizing efficiency in SpriteKit games.

![Demo Overview](https://github.com/xuxulll/XLPickerNode/raw/master/Demo/Demo.gif)

## Basic usage

Simply register cell type and add to scene. You can even use your custom class as content cell.

``` swift

let pickerNode = XLPickerNode(position: CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame)), size: CGSizeMake(view.bounds.size.width, view.bounds.size.height / 2))

/**
*  Remark: You must call registerCalss(_, withReusableIdentifier:) for reusing
*/
pickerNode.registerClass(SKLabelNode.self, withReusableIdentifier: "pickerCell")

pickerNode.delegate = self
pickerNode.dataSource = self
        
self.addChild(pickerNode)
        
pickerNode.reloadData() //Remember to call reloadData() after configuration.

```

## Delegate and Data Source

You can notify XLPickerNode by using delegate and data source methods. Data source of XLPickerNode must be set since it provides necessary data for calculating related data. 

### Data Source
You can have mutiple components for one XLPickerNode. `func numberOfComponentsInPickerNode(pickerNode: XLPickerNode)` is a optional data source methods. Default value is 1 if not implemented.
``` swift
optional func numberOfComponentsInPickerNode(pickerNode: XLPickerNode) -> Int
```

Other necessary data source methods you must implement:
``` swift
/**
*  Number of rows in component
*/

func pickerNode(pickerNode: XLPickerNode, numberOfRowsInComponent component: Int) -> Int


/**
*  Cell for row in component
*/

func pickerNode(pickerNode: XLPickerNode, cellForRow row: Int, inComponent component: Int) -> SKNode
```

### Delegate
All methods in delegate is optional.

``` swift
/**
*  Called after user dragged on the picker node or manually set selectedRow
*/
optional func pickerNode(pickerNode: XLPickerNode, didSelectRow row: Int, inComponent component: Int)

/**
*  customize component width and row height for each component
*/
optional func pickerNode(pickerNode: XLPickerNode, widthForComponent component: Int) -> CGFloat
optional func pickerNode(pickerNode: XLPickerNode, rowHeightForComponent components: Int) -> CGFloat

/**
*  called before display cell
*/
optional func pickerNode(pickerNode: XLPickerNode, willDisplayCell cell: SKNode, forRow row: Int, forComponent component: Int)
```

## 天朝子民
求勾搭，用SpriteKit的人太少了。

## License
MIT