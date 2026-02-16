package GalvanometerMeasurementSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ElectricCurrentValue :> ISQ::ElectricCurrentValue;
    attribute def PlaneAngleValue :> ISQ::PlaneAngleValue;
    attribute def TorqueValue :> ISQ::TorqueValue;
    attribute def MagneticFluxDensityValue :> ISQ::MagneticFluxDensityValue;
    attribute def AreaValue :> ISQ::AreaValue;
    attribute def SpringConstantValue :> ISQ::ForceValue;
    attribute def ResistanceValue :> ISQ::ResistanceValue;
    attribute def PotentialValue :> ISQ::PotentialValue;
    
    port def ElectricalInputPort {
        in item inputCurrent : ElectricCurrentValue;
        in item inputVoltage : PotentialValue;
    }
    
    port def MechanicalOutputPort {
        out item deflectionAngle : PlaneAngleValue;
    }
    
    port def VisualDisplayPort {
        out item indicatedValue : Real;
    }
    
    item def MagneticField {
        attribute fluxDensity : MagneticFluxDensityValue;
        attribute uniformity : Real;
    }
    
    item def MovingCoil {
        attribute numberOfTurns : Real;
        attribute effectiveArea : AreaValue;
        attribute resistance : ResistanceValue;
        attribute current : ElectricCurrentValue;
    }
    
    item def SuspensionSpring {
        attribute springConstant : SpringConstantValue;
        attribute restPosition : PlaneAngleValue;
        attribute maxDeflection : PlaneAngleValue;
    }
    
    item def PointerNeedle {
        attribute currentAngle : PlaneAngleValue;
        attribute length : ISQ::LengthValue;
    }
    
    item def CalibratedScale {
        attribute minValue : Real;
        attribute maxValue : Real;
        attribute divisions : Integer;
    }
    
    part def PermanentMagnet {
        doc /* Provides a uniform radial magnetic field for the moving coil. */
        attribute magneticField : MagneticField {
            attribute fluxDensity : MagneticFluxDensityValue;
            attribute uniformity = 0.98;
        }
    }
    
    part def CoilAssembly {
        doc /* The moving coil suspended in the magnetic field that experiences torque. */
        attribute coil : MovingCoil {
            attribute numberOfTurns = 100.0;
            attribute effectiveArea : AreaValue;
            attribute resistance : ResistanceValue;
        }
        port electricalConnection : ElectricalInputPort;
    }
    
    part def SpringMechanism {
        doc /* Provides restoring torque and electrical connection to the coil. */
        attribute spring : SuspensionSpring {
            attribute springConstant : SpringConstantValue;
            attribute restPosition : PlaneAngleValue = 0.0;
            attribute maxDeflection : PlaneAngleValue;
        }
    }
    
    part def IndicatorAssembly {
        doc /* Displays the measured value through pointer deflection on a calibrated scale. */
        attribute pointer : PointerNeedle {
            attribute currentAngle : PlaneAngleValue;
            attribute length : ISQ::LengthValue;
        }
        attribute scale : CalibratedScale {
            attribute minValue = 0.0;
            attribute maxValue = 100.0;
            attribute divisions = 100;
        }
        port displayOutput : VisualDisplayPort;
    }
    
    part def DampingSystem {
        doc /* Provides electromagnetic damping to prevent oscillations. */
        attribute dampingCoefficient : Real;
    }
    
    action def CalculateElectromagneticTorque {
        in magneticFluxDensity : MagneticFluxDensityValue;
        in coilArea : AreaValue;
        in coilTurns : Real;
        in current : ElectricCurrentValue;
        out electromagneticTorque : TorqueValue;
    }
    
    action def CalculateRestoringTorque {
        in springConstant : SpringConstantValue;
        in deflectionAngle : PlaneAngleValue;
        out restoringTorque : TorqueValue;
    }
    
    action def DetermineEquilibriumAngle {
        in electromagneticTorque : TorqueValue;
        in springConstant : SpringConstantValue;
        out equilibriumAngle : PlaneAngleValue;
    }
    
    action def ConvertAngleToReading {
        in deflectionAngle : PlaneAngleValue;
        in scaleMin : Real;
        in scaleMax : Real;
        in maxDeflection : PlaneAngleValue;
        out displayReading : Real;
    }
    
    action def MeasureElectricalQuantity {
        doc /* Primary measurement action converting electrical input to mechanical deflection. */
        in inputCurrent : ElectricCurrentValue;
        in magneticFlux : MagneticFluxDensityValue;
        in coilArea : AreaValue;
        in coilTurns : Real;
        in springK : SpringConstantValue;
        in scaleMin : Real;
        in scaleMax : Real;
        in maxAngle : PlaneAngleValue;
        out measuredValue : Real;
        out finalDeflection : PlaneAngleValue;
        
        first start;
        then action calculateEMTorque : CalculateElectromagneticTorque {
            in magneticFluxDensity = magneticFlux;
            in coilArea = MeasureElectricalQuantity::coilArea;
            in coilTurns = MeasureElectricalQuantity::coilTurns;
            in current = inputCurrent;
            out electromagneticTorque;
        }
        then action findEquilibrium : DetermineEquilibriumAngle {
            in electromagneticTorque = calculateEMTorque.electromagneticTorque;
            in springConstant = springK;
            out equilibriumAngle;
        }
        then action convertToReading : ConvertAngleToReading {
            in deflectionAngle = findEquilibrium.equilibriumAngle;
            in scaleMin = MeasureElectricalQuantity::scaleMin;
            in scaleMax = MeasureElectricalQuantity::scaleMax;
            in maxDeflection = maxAngle;
            out displayReading;
        }
        then assign finalDeflection := findEquilibrium.equilibriumAngle;
        then assign measuredValue := convertToReading.displayReading;
        then done;
    }
    
    attribute def CurrentRemovedSignal;
    
    state def GalvanometerOperationalStates {
        doc /* State machine governing galvanometer operational modes. */
        
        entry; then idle;
        
        state idle {
            doc /* No current applied, pointer at zero position. */
        }
        
        transition idle_to_energized
            first idle
            accept currentApplied : ElectricCurrentValue
            then energized;
        
        state energized {
            doc /* Current flowing, electromagnetic torque generated. */
        }
        
        transition energized_to_deflecting
            first energized
            if torqueApplied
            then deflecting;
        
        state deflecting {
            doc /* Pointer moving toward equilibrium position. */
        }
        
        transition deflecting_to_settled
            first deflecting
            if equilibriumReached
            then settled;
        
        state settled {
            doc /* Pointer at stable equilibrium, displaying measurement. */
        }
        
        transition settled_to_idle
            first settled
            accept currentRemoved : CurrentRemovedSignal
            then idle;
        
        state torqueApplied;
        state equilibriumReached;
    }
    
    part def Galvanometer {
        doc /* 
            A Galvanometer is an electromechanical instrument that detects and measures 
            small electric currents. Its primary function is to convert electrical current 
            into a proportional mechanical deflection of a pointer across a calibrated scale, 
            enabling visual indication and measurement of the current magnitude.
            
            The system operates by passing current through a coil suspended in a radial 
            magnetic field. The interaction between the current and magnetic field generates 
            an electromagnetic torque that deflects the coil against a restoring spring torque. 
            At equilibrium, the deflection angle is directly proportional to the current, 
            allowing precise measurement.
        */
        
        attribute sensitivity : Real;
        attribute fullScaleDeflection : PlaneAngleValue;
        attribute fullScaleCurrent : ElectricCurrentValue;
        attribute internalResistance : ResistanceValue;
        
        port currentInput : ElectricalInputPort;
        port mechanicalOutput : MechanicalOutputPort;
        port visualDisplay : VisualDisplayPort;
        
        part magnet : PermanentMagnet {
            attribute :>> magneticField.fluxDensity : MagneticFluxDensityValue;
        }
        
        part movingCoilAssembly : CoilAssembly {
            attribute :>> coil.numberOfTurns = 150.0;
            attribute :>> coil.effectiveArea : AreaValue;
            attribute :>> coil.resistance : ResistanceValue;
        }
        
        part suspensionSpring : SpringMechanism {
            attribute :>> spring.springConstant : SpringConstantValue;
            attribute :>> spring.maxDeflection : PlaneAngleValue;
        }
        
        part indicator : IndicatorAssembly {
            attribute :>> pointer.currentAngle : PlaneAngleValue;
            attribute :>> scale.minValue = 0.0;
            attribute :>> scale.maxValue = 100.0;
            attribute :>> scale.divisions = 100;
        }
        
        part damper : DampingSystem {
            attribute :>> dampingCoefficient = 0.7;
        }
        
        connect currentInput to movingCoilAssembly.electricalConnection;
        flow movingCoilAssembly.electricalConnection.inputCurrent to movingCoilAssembly.coil.current;
        flow indicator.pointer.currentAngle to mechanicalOutput.deflectionAngle;
        flow indicator.displayOutput to visualDisplay;
        
        perform action measure : MeasureElectricalQuantity {
            in inputCurrent = currentInput.inputCurrent;
            in magneticFlux = magnet.magneticField.fluxDensity;
            in coilArea = movingCoilAssembly.coil.effectiveArea;
            in coilTurns = movingCoilAssembly.coil.numberOfTurns;
            in springK = suspensionSpring.spring.springConstant;
            in scaleMin = indicator.scale.minValue;
            in scaleMax = indicator.scale.maxValue;
            in maxAngle = suspensionSpring.spring.maxDeflection;
            out measuredValue;
            out finalDeflection;
        }
        
        exhibit state operatingBehavior : GalvanometerOperationalStates;
    }
    
    part galvanometerInstrument : Galvanometer {
        attribute :>> sensitivity = 0.001;
        attribute :>> fullScaleDeflection : PlaneAngleValue;
        attribute :>> fullScaleCurrent : ElectricCurrentValue;
        attribute :>> internalResistance : ResistanceValue;
    }
    
    requirement def SensitivityRequirement {
        doc /* The galvanometer shall detect minimum specified current levels. */
        subject instrument : Galvanometer;
        
        require constraint minimumDetectableCurrent {
            doc /* Minimum detectable current shall not exceed specified threshold. */
        }
    }
    
    requirement def LinearityRequirement {
        doc /* Deflection shall be linearly proportional to input current. */
        subject instrument : Galvanometer;
        
        require constraint linearResponse {
            doc /* Deviation from linearity shall not exceed 2% of full scale. */
        }
    }
    
    requirement def AccuracyRequirement {
        doc /* Measurement accuracy shall meet specified tolerance. */
        subject instrument : Galvanometer;
        
        require constraint measurementTolerance {
            doc /* Total measurement error shall not exceed ±1.5% of reading. */
        }
    }
    
    requirement def ResponseTimeRequirement {
        doc /* The galvanometer shall settle to final reading within specified time. */
        subject instrument : Galvanometer;
        
        require constraint settlementTime {
            doc /* Pointer shall reach 98% of final deflection within 2 seconds. */
        }
    }
    
    requirement <'GAL-SYS-001'> galvanometerSystemRequirement {
        doc /* 
            The Galvanometer System shall accurately convert electrical current into 
            proportional mechanical deflection for measurement and visual indication, 
            meeting specified performance criteria for sensitivity, linearity, accuracy, 
            and response time.
        */
        
        subject galvSystem : Galvanometer;
        
        assume constraint operatingEnvironment {
            doc /* 
                The galvanometer operates at standard temperature (20°C ± 5°C) 
                and is isolated from external magnetic fields and vibrations.
            */
        }
        
        require sensitivity : SensitivityRequirement {
            subject instrument = galvSystem;
        }
        require linearity : LinearityRequirement {
            subject instrument = galvSystem;
        }
        require accuracy : AccuracyRequirement {
            subject instrument = galvSystem;
        }
        require responseTime : ResponseTimeRequirement {
            subject instrument = galvSystem;
        }
    }
    
    action def CalibrateGalvanometer {
        doc /* Calibration procedure to establish accurate current-to-deflection relationship. */
        in referenceCurrents : ElectricCurrentValue[*];
        in expectedDeflections : PlaneAngleValue[*];
        out calibrationFactor : Real;
        out calibrationError : Real;
        
        first start;
        then merge nextCalibrationPoint;
        
        for i in 1..referenceCurrents->size() {
            action applyCalibrationCurrent {
                in referenceCurrent = referenceCurrents#(i);
                out appliedCurrent : ElectricCurrentValue;
            }
            then action measureActualDeflection : MeasureElectricalQuantity {
                in inputCurrent = applyCalibrationCurrent.appliedCurrent;
                in magneticFlux : MagneticFluxDensityValue;
                in coilArea : AreaValue;
                in coilTurns : Real;
                in springK : SpringConstantValue;
                in scaleMin : Real;
                in scaleMax : Real;
                in maxAngle : PlaneAngleValue;
                out measuredValue;
                out finalDeflection;
            }
            then action compareDeflections {
                in measured = measureActualDeflection.finalDeflection;
                in expected = expectedDeflections#(i);
                out deviation : PlaneAngleValue;
            }
            then nextCalibrationPoint;
        }
        
        then action computeCalibrationFactor {
            out factor : Real;
            out error : Real;
        }
        then assign calibrationFactor := computeCalibrationFactor.factor;
        then assign calibrationError := computeCalibrationFactor.error;
        then done;
    }
}
