//
//  GameScene.swift
//  Demo
//
//  Created by 徐磊 on 15/8/20.
//  Copyright (c) 2015年 xuxulll. All rights reserved.
//

import SpriteKit

class GameScene: SKScene, XLPickerNodeDataSource, XLPickerNodeDelegate {
    
    var pickerNode: XLPickerNode!
    
    override func didMoveToView(view: SKView) {
        
        pickerNode = XLPickerNode(position: CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame)), size: CGSizeMake(200, 200))
        pickerNode.registerClass(SKLabelNode.self, withReusableIdentifer: "pickerCell")
        pickerNode.delegate = self
        pickerNode.dataSource = self
        
        self.addChild(pickerNode)
        
        pickerNode.reloadData()
    }
    
    func numberOfComponentsInPickerNode(pickerNode: XLPickerNode) -> Int {
        return 2
    }
    
    func pickerNode(pickerNode: XLPickerNode, numberOfRowsInComponent component: Int) -> Int {
        return 100
    }
    
    func pickerNode(pickerNode: XLPickerNode, cellForRow row: Int, inComponent component: Int) -> SKNode {
        
        
        let node = pickerNode.dequeueReusableCellWithIdentifier("pickerCell") as! SKLabelNode
        
        node.fontColor = UIColor.redColor()
        node.verticalAlignmentMode = .Center
        node.horizontalAlignmentMode = .Center
        node.fontSize = 32
        node.text = "\(component) : \(row)"
        
        return node
    }
    
    func pickerNode(pickerNode: XLPickerNode, labelNodeForRow row: Int, inComponent component: Int) -> SKLabelNode {
        let label = SKLabelNode(text: "\(component) : \(row)")
        label.fontColor = UIColor.whiteColor()
        label.fontSize = 32
        
        return label
    }
    
    func pickerNode(pickerNode: XLPickerNode, didSelectRow row: Int, inComponent component: Int) {
        println("select component: \(component), row: \(row), compupted selected row: \(pickerNode.selectedRowForComponent(component))")
    }
}
