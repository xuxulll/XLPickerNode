//
//  XLPickerNode.swift
//  createpickerNode
//
//  Created by 徐磊 on 15/7/3.
//  Copyright (c) 2015年 xuxulll. All rights reserved.
//

import SpriteKit

/**
*  Data Source
*/
@objc protocol XLPickerNodeDataSource: NSObjectProtocol {
    
    /**
    *  Number of component in picker node
    *  Default value is set to 1 if not implemented
    */
    optional func numberOfComponentsInPickerNode(pickerNode: XLPickerNode) -> Int
    
    
    /**
    *  Number of rows in component
    */
    func pickerNode(pickerNode: XLPickerNode, numberOfRowsInComponent component: Int) -> Int
    
    
    /**
    *  Cell for row in component
    */
    func pickerNode(pickerNode: XLPickerNode, cellForRow row: Int, inComponent component: Int) -> SKNode
    
}


/**
*  Delegate
*/
@objc protocol XLPickerNodeDelegate: NSObjectProtocol {
    
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
}




// MARK: - Extension for SKNode

private var cellIdentifier: NSString?

extension SKNode {
    var identifier: String? {
        get {
            return objc_getAssociatedObject(self, &cellIdentifier) as? String
        }
        
        set {
            objc_setAssociatedObject(self, &cellIdentifier, newValue, objc_AssociationPolicy(OBJC_ASSOCIATION_COPY_NONATOMIC))
        }
    }
    
    func prepareForReuse() {
        
        /**
        *  Clear all action
        */
        self.removeAllActions()
        for child in self.children {
            (child as! SKNode).removeAllActions()
        }
    }
}


// MARK: - XLPickerNode

@availability(iOS, introduced=7.0)
class XLPickerNode: SKNode, UIGestureRecognizerDelegate {
    
    weak var dataSource: XLPickerNodeDataSource?
    weak var delegate: XLPickerNodeDelegate?
    
    
    /// general config of row height for each component
    /// will be overrided if delegate methods are implemented
    var rowHeight: CGFloat = 44.0
    
    
    //MARK: Computed Data
    
    /// Methods
    
    /**
    * info fetched from the data source and will be cached
    */
    func numberOfComponents() -> Int {
        if _numberOfComponents == -1 {
            _numberOfComponents = dataSource?.numberOfComponentsInPickerNode?(self) ?? 1
        }
        return _numberOfComponents
    }
    
    func numberOfRowsInComponent(Component: Int) -> Int {
        return dataSource!.pickerNode(self, numberOfRowsInComponent: Component)
    }
    
    func contentSizeForComponent(component: Int) -> CGSize {
        return contentNodes[component].frame.size
    }
    
    func rowHeightForComponent(component: Int) -> CGFloat {
        return componentRowHeights[component]
    }
    
    func widthForComponent(component: Int) -> CGFloat {
        return componentWidths[component]
    }
    
    /// Computed properties
    private var _maxRowHeight: CGFloat {
        var maxHeight: CGFloat = 0.0
        for height in componentRowHeights {
            maxHeight = max(maxHeight, height)
        }
        
        return maxHeight
    }
    
    //MARK: Data affecting UI
    
    /// set during initialization, read-only to public
    private(set) var size: CGSize
    
    /// default to show indicator
    var showsSelectionIndicator: Bool = true {
        didSet {
            if showsSelectionIndicator {
                /**
                *  Re-initialize indicator node since we deinit it when hiding indicator
                */
                indicatorNode = SKSpriteNode(color: indicatorColor, size: CGSizeMake(size.width, _maxRowHeight))
                backgroundNode.addChild(indicatorNode!)
            } else {
                /**
                *  Release indicator node when hide indicator
                */
                indicatorNode?.removeFromParent()
                indicatorNode = nil
            }
        }
    }
    
    var indicatorColor: UIColor = UIColor.whiteColor() {
        didSet {
            indicatorNode?.color = indicatorColor
        }
    }
    
    /// Set background color or texture
    var backgroundColor: UIColor = UIColor.clearColor() {
        didSet {
            if backgroundColor == UIColor.clearColor() {
                colorNode?.removeFromParent()
                colorNode = nil
            } else {
                if colorNode == nil {
                    colorNode = SKSpriteNode(color: backgroundColor, size: size)
                    self.addChild(colorNode!)
                } else {
                    colorNode?.color = backgroundColor
                }
            }
        }
    }
    
    var backgroundTexture: SKTexture? {
        didSet {
            if backgroundTexture == nil {
                colorNode?.removeFromParent()
                colorNode = nil
            } else {
                if colorNode == nil {
                    colorNode = SKSpriteNode(texture: backgroundTexture, size: size)
                    self.addChild(colorNode!)
                } else {
                    colorNode?.texture = backgroundTexture
                }
            }
        }
    }
    
    /// default to enable scroll
    var scrollEnabled: Bool = true {
        didSet {
            if scrollEnabled {
                /**
                *  re-initialize pan gesture and add to view since we released it for avoid crash for scene transit
                */
                if panGesture == nil {
                    panGesture = UIPanGestureRecognizer(target: self, action: "panGestureDiDTriggered:")
                    panGesture!.delegate = self
                    self.scene?.view?.addGestureRecognizer(panGesture!)
                }
                self.userInteractionEnabled = true
            } else {
                /**
                *  Remove gesture from view for disable scroll and avoid crash after new scene is presented
                */
                if panGesture != nil {
                    self.scene!.view!.removeGestureRecognizer(panGesture!)
                    panGesture = nil
                }
                self.userInteractionEnabled = false
            }
        }
    }
    
    //MARK: Nested nodes
    private var maskedNode: SKCropNode!
    private var colorNode: SKSpriteNode?
    private var backgroundNode: SKNode!
    private var contentNodes = [SKSpriteNode]()
    private var indicatorNode: SKSpriteNode?
    
    /// bound to current drag node
    private weak var currentActionNode: SKSpriteNode?
    
    
    //MARK: Stored properties
    private var identifiers = [String: String]()
    private var reusableCells = [String: [SKNode]]()
    private var visibleItems = [Int: [Int: SKNode]]()
    
    private var componentWidths = [CGFloat]()
    private var componentRowHeights = [CGFloat]()
    
    private var maxRows = [Int]()
    
    private var _numberOfComponents: Int = -1
    
    /* Gesture handler */
    private var panGesture: UIPanGestureRecognizer?
    private var kScrollDuration: NSTimeInterval = 5.0
    
    
    
    //MARK: - Initializers
    
    init(position: CGPoint, size: CGSize) {
        
        self.size = size
        
        super.init()
        
        self.position = position
    }
    
    convenience override init() {
        self.init(position: CGPointZero, size: CGSizeZero)
    }

    required init?(coder aDecoder: NSCoder) {
        self.size = CGSizeZero
        
        super.init(coder: aDecoder)
    }
    
    /**
    Register class for reusable cell.
    
    :param: className  Class that will be registered to XLPickerNode. The Class should be SKNode or its subclass
    :param: identifier Reusable identifier
    */
    func registerClass(className: AnyClass, withReusableIdentifer identifier: String) {
        identifiers[identifier] = "\(NSStringFromClass(className))"
    }
    
    
    //MARK: - Deinitializers
    
    deinit {
        println("XLPickerNode: deinit.")
        removeGestures()
    }
    
    override func removeFromParent() {
        /**
        *  Remove gesture to avoid crash when picker node is deinited while pan gesture still refers to the node.
        */
        removeGestures()
        
        super.removeFromParent()
    }
    
    private func removeGestures() {
        if panGesture != nil {
            self.scene!.view!.removeGestureRecognizer(panGesture!)
            panGesture = nil
            //println("XLPickerNode: Pan gesture is successfully removed.")
        }
    }
    
    
    //MARK: - Methods
    
    //MARK: Cell reuse
    func dequeueReusableCellWithIdentifier(identifier: String) -> AnyObject? {
        if identifiers.isEmpty {
            fatalError("XLPickerNode: No class is registered for reusable cell.")
        }
        if let array = reusableCells[identifier] {
            if var element = array.last {
                reusableCells[identifier]!.removeLast()
                element.prepareForReuse()
                return element
            }
        }
        
        let nodeClass = NSClassFromString(identifiers[identifier]) as! SKNode.Type
        return nodeClass()
    }
    
    private func enqueueReusableCell(cell: SKNode) {
        if let identifer = cell.identifier {
            var array = reusableCells[identifer] ?? [SKNode]()
            if array.isEmpty {
                reusableCells[identifer] = array
            }
            array.append(cell)
            //println("reusable count: \(array.count)")
        }
    }
    
    private func layoutCellsForComponent(component: Int) {
        let visibleRect = visibleRectForComponent(component)
        
        let oldVisibleRows = rowsForVisibleCellsInComponent(component)
        let newVisibleRows = rowsForCellInRect(visibleRect, forComponent: component)
        
        var rowsToRemove = NSMutableArray(array: oldVisibleRows)
        rowsToRemove.removeObjectsInArray(newVisibleRows)
        
        var rowsToAdd = NSMutableArray(array: newVisibleRows)
        rowsToAdd.removeObjectsInArray(oldVisibleRows)
        
        for row in rowsToRemove {
            if let cell = cellForRow(row as! Int, forComponent: component) {
                enqueueReusableCell(cell)
                cell.removeFromParent()
                visibleItems[component]?.removeValueForKey(row as! Int)
            }
        }
        
        let size = CGSizeMake(widthForComponent(component), rowHeightForComponent(component))
        
        for row in rowsToAdd {
            
            var node = dataSource?.pickerNode(self, cellForRow: row as! Int, inComponent: component)
            
            assert(node != nil, "XLPickerNode: Unexpected to find optional nil in content cell. At lease one delegate method for returning picker cell.")
            
            contentNodes[component].addChild(node!)
            
            let n = Array(identifiers.keys)[0]
            node?.identifier = Array(identifiers.keys)[0]
            
            let info = positionAndSizeForRow(row as! Int, forComponent: component)
            node!.position = info.position
            node?.zPosition = 100
            
            delegate?.pickerNode?(self, willDisplayCell: node!, forRow: row as! Int, forComponent: component)
            
            if visibleItems[component] == nil {
                visibleItems[component] = [Int: SKNode]()
            }
            visibleItems[component]![row as! Int] = node!
        }
        
    }
    
    
    //MARK: - Data Handler
    
    func reloadData() {
        
        if dataSource == nil {
            return
        }
        
        prepareForPickerNode()
        
        for component in 0 ..< numberOfComponents() {
            
            layoutCellsForComponent(component)
            
            updateAlphaForRow(0, forComponent: component)
        }
    }
    
    /**
    *  called when reloadData()
    */
    private func prepareForPickerNode() {
        
        /**
        *  Nested methods. Only called when prepareForPickerNode() is called.
        */
        func reloadParentNodes() {
            
            backgroundNode.removeAllChildren()
            
            componentWidths = []
            componentRowHeights = []
            contentNodes = []
            maxRows = []
            
            if delegate != nil && delegate!.respondsToSelector("pickerNode:widthForComponent:") {
                for s in 0 ..< numberOfComponents() {
                    componentWidths.append(delegate!.pickerNode!(self, widthForComponent: s))
                }
            } else {
                let fixedWidth = size.width / CGFloat(numberOfComponents())
                for s in 0 ..< numberOfComponents() {
                    componentWidths.append(fixedWidth)
                }
            }
            
            if delegate != nil && delegate!.respondsToSelector("pickerNode:rowHeightForComponent:") {
                for s in 0 ..< numberOfComponents() {
                    let height = delegate!.pickerNode!(self, rowHeightForComponent: s)
                    componentRowHeights.append(height)
                }
            } else {
                for _ in 0 ..< numberOfComponents() {
                    componentRowHeights.append(rowHeight)
                }
            }
            
            for height in componentRowHeights {
                let rows = ceil(size.height / height)
                maxRows.append(Int(rows))
            }
            
            for (index, componentWidth) in enumerate(componentWidths) {
                let contentNode = SKSpriteNode(
                    color: UIColor.clearColor(),
                    size: CGSizeMake(
                        componentWidth,
                        componentRowHeights[index] * CGFloat(numberOfRowsInComponent(index)
                        )
                    )
                )
                contentNode.anchorPoint = CGPointMake(0, 1)
                var accuWidth: CGFloat = -size.width / 2
                for i in 0 ..< index {
                    accuWidth += componentWidths[i]
                }
                contentNode.position = CGPointMake(accuWidth, rowHeightForComponent(index) / 2)
                contentNode.identifier = "_contentNode"
                contentNode.userData = NSMutableDictionary(dictionary: ["_component": index])
                backgroundNode.addChild(contentNode)
                contentNodes.append(contentNode)
            }
        }
        
        if maskedNode == nil {
            maskedNode = SKCropNode()
            self.addChild(maskedNode)
            
            backgroundNode = SKNode()
            maskedNode.addChild(backgroundNode)
            backgroundNode.zPosition = -1000
        }
        
        
        /**
        *  Re-mask
        */
        let mask = SKSpriteNode(color: UIColor.blackColor(), size: size)
        maskedNode.maskNode = mask
        
        /**
        *  reload all components in self
        */
        reloadParentNodes()
        
        
        if showsSelectionIndicator && indicatorNode == nil {
            indicatorNode = SKSpriteNode(color: indicatorColor, size: CGSizeMake(size.width, _maxRowHeight))
            backgroundNode.addChild(indicatorNode!)
            indicatorNode?.size = CGSizeMake(size.width, _maxRowHeight)
        }
        
        if scrollEnabled && panGesture == nil {
            panGesture = UIPanGestureRecognizer(target: self, action: "panGestureDiDTriggered:")
            panGesture!.delegate = self
            self.scene!.view!.addGestureRecognizer(panGesture!)
        }
    }
    
    
    // selection. in this case, it means showing the appropriate row in the middle
    // scrolls the specified row to center.
    func selectRow(row: Int, forComponent component: Int, animated: Bool) {
        
        currentActionNode = contentNodes[component]
        
        if animated {
            
            let rawPnt = contentNodes[component].position
            let newPosition = positionAndSizeForRow(row, forComponent: component).position
            
            currentNodeAnimateMoveToPosition(CGPointMake(rawPnt.x, -newPosition.y), fromPoint: rawPnt, duration: kScrollDuration)
            
        } else  {
            let rawPnt = contentNodes[component].position
            let newPosition = positionAndSizeForRow(row, forComponent: component).position
            
            currentActionNode!.position = CGPointMake(rawPnt.x, -newPosition.y)
            
            delegate?.pickerNode?(self, didSelectRow: row, inComponent: component)
        }
    }
    
    // returns selected row. -1 if nothing selected
    func selectedRowForComponent(component: Int) -> Int {
        
        return max(0, min(Int((contentNodes[component].position.y/* + contentNodes[component].size.height / 2*/) / rowHeightForComponent(component)), numberOfRowsInComponent(component) - 1))
    }
    
    //MARK: - Data calculations
    
    //MARK: Reusable
    private func visibleRectForComponent(component: Int) -> CGRect {
        let node = contentNodes[component]
        return CGRectMake(0, node.position.y - rowHeightForComponent(component) / 2 - size.height / 2, widthForComponent(component), size.height)
    }
    
    private func rowsForVisibleCellsInComponent(component: Int) -> [Int] {
        var rows = [Int]()
        
        if let comps = visibleItems[component] {
            
            for (key, _) in comps {
                rows.append(key)
            }
            
            return rows
        }
        return [Int]()
    }
    
    private func rowsForCellInRect(rect: CGRect, forComponent component: Int) -> [Int] {
        var rows = [Int]()
        
        for row in 0 ..< numberOfRowsInComponent(component) {
            var cellRect = rectForCellAtRow(row, inComponent: component)
            
            if CGRectIntersectsRect(cellRect, rect) {
                rows.append(row)
            }
        }
        
        return rows
    }
    
    private func rectForCellAtRow(row: Int, inComponent component: Int) -> CGRect {
        return CGRectMake(0, rowHeightForComponent(component) * CGFloat(row), widthForComponent(component), rowHeightForComponent(component))
    }
    
    private func cellForRow(row: Int, forComponent component: Int) -> SKNode? {
        
        if let componentCells = visibleItems[component] {
            return componentCells[row]
        }
        
        return nil
    }
    
    
    //MARK: Position and size
    
    /**
    Position and size for a specific row and component
    
    :param: row       row
    :param: component component
    
    :returns: Cell Info<Tuple> (position, size)
    */
    private func positionAndSizeForRow(row: Int, forComponent component: Int) -> (position: CGPoint, size: CGSize) {
        func positionForRow(row: Int, forComponent component: Int) -> CGPoint {
            let rowHeight = -rowHeightForComponent(component)
            let totalHeight = CGFloat(row) * rowHeight + rowHeight * 0.5
            
            return CGPointMake(widthForComponent(component) / 2, totalHeight)
        }
        
        func sizeForRow(row: Int, forComponent component: Int) -> CGSize {
            return CGSizeMake(widthForComponent(component), rowHeightForComponent(component))
        }
        
        return (positionForRow(row, forComponent: component), sizeForRow(row, forComponent: component))
    }
    
    /**
    Nearest anchor of cell for current drag location
    
    :param: point     drag location
    :param: component component number for calculation
    
    :returns: nearest anchor point
    */
    private func contentOffsetNearPoint(point: CGPoint, inComponent component: Int) -> CGPoint {
        var mult = round((point.y + rowHeightForComponent(component) / 2) / rowHeightForComponent(component))
        let info = positionAndSizeForRow(Int(mult) - 1, forComponent: component)
        return CGPointMake(info.position.x, -info.position.y)
    }
    
    
    private func calculateThresholdYOffsetWithPoint(point: CGPoint, forComponent component: Int) -> CGPoint {
        var retVal = point
        
        retVal.x = contentNodes[component].position.x
        
        retVal.y = max(retVal.y, minYOffsetForComponents(component))
        retVal.y = min(retVal.y, maxYOffsetForComponent(component))
        
        return retVal
    }
    
    private func minYOffsetForComponents(component: Int) -> CGFloat {
        return rowHeightForComponent(component) / 2
    }
    
    private func maxYOffsetForComponent(component: Int) -> CGFloat {
        return contentSizeForComponent(component).height - rowHeightForComponent(component) / 2
    }
    
    
    //MARK: - Gesture Handler
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
        
        let touchLocation = touch.locationInNode(self)
        weak var tNode: SKSpriteNode?
        for node in (self.nodesAtPoint(touchLocation) as! [SKNode]) {
            if node.identifier == "_contentNode" {
                currentActionNode = node as? SKSpriteNode
                return true
            }
        }
        
        return false
    }
    
    
    func panGestureDiDTriggered(recognizer: UIPanGestureRecognizer) {
        
        if recognizer.state == .Began {
            
            currentActionNode!.removeAllActions()
            
        } else if recognizer.state == .Changed {
            
            var translation = recognizer.translationInView(recognizer.view!)
            translation.y = -translation.y
            
            let pos = CGPointMake(currentActionNode!.position.x, currentActionNode!.position.y + translation.y)
            
            currentActionNode!.position = pos
            
            recognizer.setTranslation(CGPointZero, inView: recognizer.view!)
            
            let component = currentActionNode!.userData!.valueForKey("_component")!.integerValue
            
            layoutCellsForComponent(component)
            
            let row = round((pos.y + rowHeightForComponent(component) / 2) / rowHeightForComponent(component)) - 1
            
            updateAlphaForRow(Int(row), forComponent: component)
            
        } else if recognizer.state == .Ended {
            
            if let component = find(contentNodes, currentActionNode!) {
                let velocity = recognizer.velocityInView(recognizer.view!)
                let rawPnt = currentActionNode!.position
                
                var newPosition = CGPointMake(rawPnt.x, rawPnt.y - velocity.y)
                newPosition = contentOffsetNearPoint(newPosition, inComponent: component)
                let endPoint = calculateThresholdYOffsetWithPoint(newPosition, forComponent: component)
                
                var duration = kScrollDuration
                if !CGPointEqualToPoint(newPosition, endPoint) {
                    duration = 0.5
                }
                currentNodeAnimateMoveToPosition(endPoint, fromPoint: rawPnt, duration: duration)
            }
        }
    }
    
    //MARK: - UI Update
    private func currentNodeAnimateMoveToPosition(endPoint: CGPoint, fromPoint startPoint: CGPoint, duration: NSTimeInterval) {
        
        let component = currentActionNode!.userData!.valueForKey("_component")!.integerValue
        
        let moveBlock = SKAction.customActionWithDuration(duration, actionBlock: { [unowned self](node, elapsedTime) -> Void in
            
            func easeStep(p: CGFloat) -> CGFloat {
                let f: CGFloat = (p - 1)
                return f * f * f * (1 - p) + 1
            }
            
            let t = CGFloat(elapsedTime) / CGFloat(duration)
            
            let x = startPoint.x + easeStep(t) * (endPoint.x - startPoint.x);
            let y = startPoint.y + easeStep(t) * (endPoint.y - startPoint.y);
            let targetPoint = CGPointMake(x, y)
            node.position = targetPoint
            
            self.layoutCellsForComponent(component)
            
            let row = Int(round((node.position.y + self.rowHeightForComponent(component) / 2) / self.rowHeightForComponent(component))) - 1
            
            self.updateAlphaForRow(row, forComponent: component)
        })
        
        let finishBlock = SKAction.runBlock({ [unowned self]() -> Void in
            dispatch_async(dispatch_get_main_queue(), { [unowned self]() -> Void in
                self.delegate?.pickerNode?(self, didSelectRow: selectedRowForComponent(component), inComponent: component)
            })
        })
        
        currentActionNode!.runAction(SKAction.sequence([moveBlock, finishBlock]))
    }
    
    
    private func updateAlphaForRow(row: Int, forComponent component: Int) {
        
        let scope = CGFloat(maxRows[component] - 1) / 2
        let reloadRow = CGFloat(maxRows[component] + 1) / 2
        let step: CGFloat = 1.0 / reloadRow
        var currentStep: CGFloat = step
        for cRow in (row - Int(scope))...(row + Int(scope)) {
            
            cellForRow(cRow, forComponent: component)?.alpha = currentStep
            currentStep += cRow < row ? step : -step
        }
        
    }
    
}
