package 'Thorpe Tube Flowmeter System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def FlowRateValue :> ISQ::VolumeFlowRateValue;
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def LengthValue :> ISQ::LengthValue;
    attribute def MassValue :> ISQ::MassValue;
    attribute def DensityValue :> ISQ::DensityValue;
    attribute def AreaValue :> ISQ::AreaValue;
    attribute def VelocityValue :> ISQ::SpeedValue;
    attribute def ForceValue :> ISQ::ForceValue;
    attribute def AngleValue :> ISQ::PlaneAngleValue;
    
    attribute def GasFlowStarted;
    attribute def GasFlowStopped;
    attribute def FlowStopCommand;
    
    item def MedicalGas {
        attribute density : DensityValue;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute velocity : VelocityValue;
    }
    
    item def FloatElement {
        attribute mass : MassValue;
        attribute diameter : LengthValue;
        attribute crossSectionalArea : AreaValue;
        attribute verticalPosition : LengthValue;
    }
    
    port def GasInletPort {
        in item gas : MedicalGas;
        attribute inletPressure : PressureValue;
        attribute inletFlowRate : FlowRateValue;
    }
    
    port def GasOutletPort {
        out item gas : MedicalGas;
        attribute outletPressure : PressureValue;
        attribute outletFlowRate : FlowRateValue;
    }
    
    port def FlowIndicationPort {
        out attribute indicatedFlowRate : FlowRateValue;
        out attribute floatHeight : LengthValue;
    }
    
    part def TaperedGlassTube {
        attribute tubeLength : LengthValue;
        attribute bottomDiameter : LengthValue;
        attribute topDiameter : LengthValue;
        attribute taperAngle : AngleValue;
        attribute materialTransparency : Real;
        
        port inlet : GasInletPort;
        port outlet : GasOutletPort;
        
        part floatBall : FloatElement;
        
        constraint geometricTaper {
            doc /* The tube diameter increases linearly from bottom to top */
            topDiameter > bottomDiameter
        }
    }
    
    part def CalibrationScale {
        attribute minimumFlowRate : FlowRateValue;
        attribute maximumFlowRate : FlowRateValue;
        attribute scaleLength : LengthValue;
        attribute numberOfGraduations : Integer;
        attribute calibrationGasDensity : DensityValue;
        
        port indication : FlowIndicationPort;
        
        constraint scaleRange {
            maximumFlowRate > minimumFlowRate and
            minimumFlowRate >= 0.0
        }
    }
    
    part def ProtectiveHousing {
        attribute maxOperatingPressure : PressureValue;
        attribute structuralIntegrity : Real;
        attribute mountingOrientation : String;
    }
    
    part def FlowControlValve {
        attribute valvePosition : Real;
        attribute maxFlowCapacity : FlowRateValue;
        
        action def AdjustValve {
            in desiredFlow : FlowRateValue;
            out newPosition : Real;
        }
    }
    
    action def DetermineFloatEquilibrium {
        in gasFlowRate : FlowRateValue;
        in gasDensity : DensityValue;
        in tubeBottomDiameter : LengthValue;
        in tubeTopDiameter : LengthValue;
        in tubeLength : LengthValue;
        in floatMass : MassValue;
        in floatDiameter : LengthValue;
        out equilibriumHeight : LengthValue;
        out dragForce : ForceValue;
        out buoyantForce : ForceValue;
    }
    
    action def ConvertPositionToFlowRate {
        in floatPosition : LengthValue;
        in scaleMin : FlowRateValue;
        in scaleMax : FlowRateValue;
        in scaleLength : LengthValue;
        out indicatedFlow : FlowRateValue;
    }
    
    action def MeasureGasFlow {
        in item incomingGas : MedicalGas;
        in tubeGeometry : TaperedGlassTube;
        in scaleCalibration : CalibrationScale;
        out measuredFlowRate : FlowRateValue;
        out floatPosition : LengthValue;
        
        first start;
        then action admitGas {
            in item gas = incomingGas;
            doc /* Gas enters through bottom of tapered tube */
        }
        then action calculateEquilibrium : DetermineFloatEquilibrium {
            in gasFlowRate = incomingGas.flowRate;
            in gasDensity = incomingGas.density;
            in tubeBottomDiameter = tubeGeometry.bottomDiameter;
            in tubeTopDiameter = tubeGeometry.topDiameter;
            in tubeLength = tubeGeometry.tubeLength;
            in floatMass = tubeGeometry.floatBall.mass;
            in floatDiameter = tubeGeometry.floatBall.diameter;
            out equilibriumHeight;
            out dragForce;
            out buoyantForce;
        }
        then action readScale : ConvertPositionToFlowRate {
            in floatPosition = calculateEquilibrium.equilibriumHeight;
            in scaleMin = scaleCalibration.minimumFlowRate;
            in scaleMax = scaleCalibration.maximumFlowRate;
            in scaleLength = scaleCalibration.scaleLength;
            out indicatedFlow;
        }
        then assign floatPosition := calculateEquilibrium.equilibriumHeight;
        then assign measuredFlowRate := readScale.indicatedFlow;
        then done;
    }
    
    state def FlowmeterOperationalStates {
        entry; then noFlow;
        
        state noFlow {
            entry assign currentFlowRate := 0.0;
            doc /* Float rests at bottom of tube */
            attribute currentFlowRate : Real;
        }
        
        transition noFlow_to_flowInitiation
            first noFlow
            accept when GasFlowStarted
            then flowInitiation;
        
        state flowInitiation {
            doc /* Gas begins entering tube, float starts rising */
            attribute floatMoving : Boolean = true;
        }
        
        transition flowInitiation_to_stabilizing
            first flowInitiation
            if flowInitiation.floatMoving
            then stabilizing;
        
        state stabilizing {
            doc /* Float position adjusting to equilibrium */
            attribute floatStabilized : Boolean = false;
            
            state rising {
                doc /* Drag force exceeds weight, float ascending */
            }
            
            state falling {
                doc /* Weight exceeds drag force, float descending */
            }
        }
        
        transition stabilizing_to_steadyState
            first stabilizing
            if stabilizing.floatStabilized
            then steadyState;
        
        state steadyState {
            doc /* Float at equilibrium position, flow rate constant */
            attribute flowRateChanged : Boolean = false;
            attribute flowExceedsMaximum : Boolean = false;
        }
        
        transition steadyState_to_stabilizing
            first steadyState
            if steadyState.flowRateChanged
            then stabilizing;
        
        transition steadyState_to_noFlow
            first steadyState
            accept when GasFlowStopped
            then noFlow;
        
        state overrange {
            doc /* Flow rate exceeds maximum scale reading */
            attribute flowWithinRange : Boolean = false;
        }
        
        transition steadyState_to_overrange
            first steadyState
            if steadyState.flowExceedsMaximum
            then overrange;
        
        transition overrange_to_steadyState
            first overrange
            if overrange.flowWithinRange
            then steadyState;
    }
    
    action def OperateThorpeTubeFlowmeter {
        in targetFlowRate : FlowRateValue;
        in item gasSupply : MedicalGas;
        out displayedFlowRate : FlowRateValue;
        out floatElevation : LengthValue;
        
        first start;
        then action initiateFlow {
            send GasFlowStarted;
        }
        then loop {
            action measureContinuously : MeasureGasFlow {
                in item incomingGas = gasSupply;
                out measuredFlowRate;
                out floatPosition;
            }
            then assign displayedFlowRate := measureContinuously.measuredFlowRate;
            then assign floatElevation := measureContinuously.floatPosition;
            then decide;
                if abs(measureContinuously.measuredFlowRate - targetFlowRate) <= 0.1 
                    then maintainFlow;
                if abs(measureContinuously.measuredFlowRate - targetFlowRate) > 0.1 
                    then adjustFlow;
            
            action maintainFlow {
                doc /* Flow rate is within acceptable tolerance */
            }
            then continueOperation;
            
            action adjustFlow {
                doc /* Adjust upstream valve to achieve target flow */
            }
            then continueOperation;
            
            merge continueOperation;
            accept when FlowStopCommand then stopFlow;
        }
        action stopFlow {
            send GasFlowStopped;
        }
        then done;
    }
    
    requirement def <'REQ-FUNC-001'> PrimaryFlowMeasurementFunction {
        doc /* The Thorpe tube flowmeter shall measure and indicate the volumetric 
             flow rate of medical gas by utilizing the equilibrium position of a 
             float within a vertically oriented tapered tube, where the float rises 
             or falls until drag force from gas flow balances gravitational force. */
        
        subject flowmeter : ThorpeTubeFlowmeter;
        
        require constraint {
            flowmeter.operatingOrientation == "vertical" and
            flowmeter.tube.floatBall.verticalPosition >= 0.0
        }
    }
    
    requirement def <'REQ-PERF-001'> MeasurementAccuracyRequirement {
        doc /* The flowmeter shall indicate volumetric flow rate with an accuracy 
             of ±5% of full scale reading under standard operating conditions. */
        
        subject flowmeter : ThorpeTubeFlowmeter;
        
        require constraint {
            flowmeter.measurementAccuracy <= 0.05
        }
    }
    
    requirement def <'REQ-PERF-002'> FlowRangeRequirement {
        doc /* The flowmeter shall measure flow rates across the calibrated range 
             from minimum to maximum specified on the scale. */
        
        subject scale : CalibrationScale;
        
        require constraint {
            scale.minimumFlowRate >= 0.0 and
            scale.maximumFlowRate > scale.minimumFlowRate
        }
    }
    
    requirement def <'REQ-DESIGN-001'> VisualReadabilityRequirement {
        doc /* The flowmeter housing and tube shall provide unobstructed visual 
             observation of the float position against the calibrated scale. */
        
        subject tube : TaperedGlassTube;
        
        require constraint {
            tube.materialTransparency >= 0.90
        }
    }
    
    requirement def <'REQ-SAFETY-001'> PressureContainmentRequirement {
        doc /* The flowmeter housing shall safely contain gas at pressures up to 
             the specified maximum operating pressure without structural failure. */
        
        subject housing : ProtectiveHousing;
        
        require constraint {
            housing.maxOperatingPressure >= 10.0 and
            housing.structuralIntegrity >= 0.95
        }
    }
    
    requirement def <'REQ-OPER-001'> VerticalOrientationRequirement {
        doc /* The flowmeter shall be mounted and operated in a vertical orientation 
             to ensure proper float operation under gravitational force. */
        
        subject housing : ProtectiveHousing;
        
        require constraint {
            housing.mountingOrientation == "vertical"
        }
    }
    
    part def ThorpeTubeFlowmeter {
        doc /* A variable-area flowmeter that measures volumetric flow rate of gases 
             by balancing the upward drag force from flowing gas against the downward 
             gravitational force on a float within a vertically mounted tapered glass 
             tube. The float rises to an equilibrium height proportional to flow rate, 
             which is read against a calibrated scale. */
        
        attribute measurementAccuracy : Real;
        attribute operatingOrientation : String;
        attribute calibrationGasType : String;
        
        port gasInlet : GasInletPort;
        port gasOutlet : GasOutletPort;
        port flowDisplay : FlowIndicationPort;
        
        part tube : TaperedGlassTube {
            port redefines inlet = ThorpeTubeFlowmeter::gasInlet;
            port redefines outlet = ThorpeTubeFlowmeter::gasOutlet;
        }
        
        part scale : CalibrationScale {
            port redefines indication = ThorpeTubeFlowmeter::flowDisplay;
        }
        
        part housing : ProtectiveHousing;
        
        part controlValve : FlowControlValve;
        
        connection floatToScaleReading connect tube.floatBall to scale;
        connection valveToInlet connect controlValve to tube.inlet;
        
        perform action primaryOperation : OperateThorpeTubeFlowmeter {
            in targetFlowRate;
            in item gasSupply;
            out displayedFlowRate;
            out floatElevation;
        }
        
        exhibit state operatingBehavior : FlowmeterOperationalStates;
    }
    
    part thorpeTubeFlowmeterInstance : ThorpeTubeFlowmeter {
        attribute redefines measurementAccuracy = 0.04;
        attribute redefines operatingOrientation = "vertical";
        attribute redefines calibrationGasType = "oxygen";
        
        part redefines tube : TaperedGlassTube {
            attribute redefines tubeLength = 150.0;
            attribute redefines bottomDiameter = 6.0;
            attribute redefines topDiameter = 14.0;
            attribute redefines taperAngle = 3.0;
            attribute redefines materialTransparency = 0.95;
            
            part redefines floatBall : FloatElement {
                attribute redefines mass = 2.8;
                attribute redefines diameter = 5.5;
                attribute redefines crossSectionalArea = 23.76;
            }
        }
        
        part redefines scale : CalibrationScale {
            attribute redefines minimumFlowRate = 0.5;
            attribute redefines maximumFlowRate = 15.0;
            attribute redefines scaleLength = 140.0;
            attribute redefines numberOfGraduations = 30;
            attribute redefines calibrationGasDensity = 1.429;
        }
        
        part redefines housing : ProtectiveHousing {
            attribute redefines maxOperatingPressure = 12.0;
            attribute redefines structuralIntegrity = 0.98;
            attribute redefines mountingOrientation = "vertical";
        }
        
        part redefines controlValve : FlowControlValve {
            attribute redefines valvePosition = 0.5;
            attribute redefines maxFlowCapacity = 20.0;
        }
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for Thorpe tube flowmeter system */
        
        require primaryFunction : PrimaryFlowMeasurementFunction {
            subject = thorpeTubeFlowmeterInstance;
        }
        
        require measurementAccuracy : MeasurementAccuracyRequirement {
            subject = thorpeTubeFlowmeterInstance;
        }
        
        require flowRange : FlowRangeRequirement {
            subject = thorpeTubeFlowmeterInstance.scale;
        }
        
        require visualReadability : VisualReadabilityRequirement {
            subject = thorpeTubeFlowmeterInstance.tube;
        }
        
        require pressureContainment : PressureContainmentRequirement {
            subject = thorpeTubeFlowmeterInstance.housing;
        }
        
        require verticalOrientation : VerticalOrientationRequirement {
            subject = thorpeTubeFlowmeterInstance.housing;
        }
    }
}
