import WinChocolate

let nibObjectGraphXIB = """
<?xml version="1.0" encoding="UTF-8"?>
<document type="com.apple.InterfaceBuilder3.Cocoa.XIB" version="3.0" toolsVersion="22505">
    <dependencies>
        <plugIn identifier="com.apple.InterfaceBuilder.CocoaPlugin" version="22505"/>
    </dependencies>
    <objects>
        <customObject id="-2" userLabel="File's Owner" customClass="PanelOwner"/>
        <customObject id="-1" userLabel="First Responder" customClass="FirstResponder"/>
        <customObject id="helper-1" userLabel="Helper" customClass="DemoHelper"/>
        <customView id="root-1" identifier="rootView">
            <rect key="frame" x="0.0" y="0.0" width="300" height="200"/>
            <subviews>
                <button id="btn-1" identifier="okButton" tag="7">
                    <rect key="frame" x="20" y="20" width="120" height="32"/>
                    <autoresizingMask key="autoresizingMask" flexibleMinY="YES"/>
                    <buttonCell key="cell" type="push" title="Press &amp; Hold" bezelStyle="rounded" id="btn-1c"/>
                    <connections>
                        <action selector="doThing:" target="-2" id="cx-1"/>
                    </connections>
                </button>
                <button id="chk-1" identifier="check">
                    <rect key="frame" x="20" y="70" width="120" height="24"/>
                    <buttonCell key="cell" type="check" title="Enable" state="on" id="chk-1c"/>
                </button>
                <textField id="fld-1" identifier="nameField">
                    <rect key="frame" x="20" y="110" width="160" height="24"/>
                    <textFieldCell key="cell" editable="YES" selectable="YES" borderStyle="bezel" drawsBackground="YES" title="Seed" placeholderString="Name" id="fld-1c"/>
                </textField>
                <slider id="sld-1" identifier="volume">
                    <rect key="frame" x="20" y="150" width="200" height="24"/>
                    <sliderCell key="cell" continuous="YES" minValue="0.0" maxValue="100" doubleValue="42" id="sld-1c"/>
                </slider>
            </subviews>
            <connections>
                <outlet property="delegate" destination="helper-1" id="cx-2"/>
            </connections>
        </customView>
    </objects>
</document>
"""

let nibWindowXIB = """
<?xml version="1.0" encoding="UTF-8"?>
<document type="com.apple.InterfaceBuilder3.Cocoa.XIB" version="3.0">
    <objects>
        <window title="Nib Window" id="w1">
            <windowStyleMask key="styleMask" titled="YES" closable="YES"/>
            <rect key="contentRect" x="120" y="120" width="320" height="200"/>
            <view key="contentView" id="cv1">
                <rect key="frame" x="0.0" y="0.0" width="320" height="200"/>
                <subviews>
                    <button id="wb1" identifier="windowButton">
                        <rect key="frame" x="20" y="20" width="100" height="30"/>
                        <buttonCell key="cell" type="push" title="In Window" id="wb1c"/>
                    </button>
                </subviews>
            </view>
        </window>
    </objects>
</document>
"""

