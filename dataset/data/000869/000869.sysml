package EccentricReducerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def RotationalSpeedValue :> ISQ::AngularVelocityValue;
    attribute def TorqueValue :> ISQ::TorqueValue;
    attribute def EccentricityValue :> ISQ::LengthValue;
    attribute def ReductionRatio :> Real;
    attribute def Efficiency :> Real;
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def LoadCapacityValue :> ISQ::ForceValue;
    attribute def AngleValue :> ISQ::PlaneAngleValue;

    item def LubricantOil {
        attribute viscosity : Real;
        attribute temperature : TemperatureValue;
        attribute flowRate : Real;
    }

    port def RotaryInputPort {
        in attribute inputSpeed : RotationalSpeedValue;
        in attribute inputTorque : TorqueValue;
    }

    port def RotaryOutputPort {
        out attribute outputSpeed : RotationalSpeedValue;
        out attribute outputTorque : TorqueValue;
    }

    port def LubricationPort {
        in item lubricant : LubricantOil;
    }

    part def InputShaft {
        attribute speed : RotationalSpeedValue;
        attribute torque : TorqueValue;
        attribute diameter : ISQ::LengthValue;
        port rotaryPort : RotaryInputPort;
    }

    part def EccentricDisc {
        attribute eccentricity : EccentricityValue;
        attribute rotationAngle : AngleValue;
        attribute mass : ISQ::MassValue;
        attribute thickness : ISQ::LengthValue;
    }

    part def CycloidalGear {
        attribute numberOfTeeth : Integer;
        attribute pitchRadius : ISQ::LengthValue;
        attribute contactForce : LoadCapacityValue;
        attribute materialStrength : ISQ::PressureValue;
    }

    part def OutputShaft {
        attribute speed : RotationalSpeedValue;
        attribute torque : TorqueValue;
        attribute diameter : ISQ::LengthValue;
        port rotaryPort : RotaryOutputPort;
    }

    part def Housing {
        attribute internalDiameter : ISQ::LengthValue;
        attribute wallThickness : ISQ::LengthValue;
        attribute operatingTemperature : TemperatureValue;
        attribute numberOfPins : Integer;
        port lubricationPort : LubricationPort;
    }

    part def BearingAssembly {
        attribute loadRating : LoadCapacityValue;
        attribute operatingTemperature : TemperatureValue;
        attribute rotationalSpeed : RotationalSpeedValue;
        attribute lubricationStatus : Boolean;
    }

    item def StartCommand;
    item def StopCommand;
    item def OverloadSignal;

    action def TransmitRotation {
        in inputSpeed : RotationalSpeedValue;
        in inputTorque : TorqueValue;
        in reductionRatio : ReductionRatio;
        in efficiency : Efficiency;
        out outputSpeed : RotationalSpeedValue;
        out outputTorque : TorqueValue;
    }

    action def GenerateEccentricMotion {
        in shaftSpeed : RotationalSpeedValue;
        in eccentricity : EccentricityValue;
        out discRotation : AngleValue;
        out orbitalMotion : AngleValue;
    }

    action def ConvertCycloidalMotion {
        in cycloidalMotion : AngleValue;
        in numberOfLobes : Integer;
        out outputRotation : AngleValue;
    }

    action def MonitorTemperature {
        in currentTemp : TemperatureValue;
        in maxTemp : TemperatureValue;
        out overheating : Boolean;
    }

    action def DistributeLubricant {
        in item lubricant : LubricantOil;
        in flowRate : Real;
        out lubricationStatus : Boolean;
    }

    action def CheckLoadCondition {
        in currentTorque : TorqueValue;
        in maxTorque : TorqueValue;
        out overloaded : Boolean;
    }

    action def PerformSpeedReduction {
        first start;
        then merge continuousOperation;
        then action generateEccentric : GenerateEccentricMotion;
        then action convertMotion : ConvertCycloidalMotion {
            in cycloidalMotion = generateEccentric.orbitalMotion;
        }
        then action transmit : TransmitRotation;
        then action monitor : MonitorTemperature;
        then action checkLoad : CheckLoadCondition;
        then decide;
            if monitor.overheating or checkLoad.overloaded then shutdown;
            if not monitor.overheating and not checkLoad.overloaded then continuousOperation;
        action shutdown;
        then done;
    }

    connection def RotaryConnection {
        end source;
        end target;
    }

    connection def MechanicalConnection {
        end driver;
        end driven;
    }

    part def EccentricReducer {
        attribute reductionRatio : ReductionRatio;
        attribute efficiency : Efficiency;
        attribute maxInputSpeed : RotationalSpeedValue;
        attribute maxOutputTorque : TorqueValue;
        attribute operatingTemp : TemperatureValue;
        attribute reducerState : String;
        
        part inputShaft : InputShaft {
            attribute speed : RotationalSpeedValue;
            attribute torque : TorqueValue;
            attribute diameter = 40.0 [mm];
        }
        
        part eccentricDisc : EccentricDisc {
            attribute eccentricity = 2.5 [mm];
            attribute rotationAngle : AngleValue;
            attribute mass = 1.2 [kg];
            attribute thickness = 15.0 [mm];
        }
        
        part cycloidalGear : CycloidalGear {
            attribute numberOfTeeth = 39;
            attribute pitchRadius = 50.0 [mm];
            attribute contactForce : LoadCapacityValue;
            attribute materialStrength = 600.0 [MPa];
        }
        
        part outputShaft : OutputShaft {
            attribute speed : RotationalSpeedValue;
            attribute torque : TorqueValue;
            attribute diameter = 35.0 [mm];
        }
        
        part housing : Housing {
            attribute internalDiameter = 150.0 [mm];
            attribute wallThickness = 8.0 [mm];
            attribute operatingTemperature : TemperatureValue;
            attribute numberOfPins = 40;
        }
        
        part inputBearing : BearingAssembly {
            attribute loadRating = 5000.0 [N];
            attribute lubricationStatus = true;
        }
        
        part outputBearing : BearingAssembly {
            attribute loadRating = 8000.0 [N];
            attribute lubricationStatus = true;
        }
        
        connection inputConnection : RotaryConnection
            connect inputShaft.rotaryPort to eccentricDisc;
        
        connection gearConnection : MechanicalConnection
            connect eccentricDisc to cycloidalGear;
        
        connection outputConnection : RotaryConnection
            connect cycloidalGear to outputShaft.rotaryPort;
        
        perform action speedReduction : PerformSpeedReduction[*] ordered;
        
        state operationalBehavior {
            entry; then idle;
            
            state idle;
            
            transition idle_to_starting
                first idle
                accept StartCommand
                then starting;
            
            state starting;
            
            transition starting_to_running
                first starting
                then running;
            
            state running;
            
            transition running_to_overload
                first running
                accept OverloadSignal
                then overload;
            
            transition running_to_stopping
                first running
                accept StopCommand
                then stopping;
            
            state overload;
            
            transition overload_to_stopping
                first overload
                then stopping;
            
            state stopping;
            
            transition stopping_to_idle
                first stopping
                then idle;
        }
    }

    part eccentricReducerSystem : EccentricReducer {
        attribute reductionRatio = 10.0;
        attribute efficiency = 0.92;
        attribute maxInputSpeed = 300.0 [SI::rad/SI::s];
        attribute maxOutputTorque = 500.0 [SI::N*SI::m];
        attribute operatingTemp = 323.15 [SI::K];
    }

    requirement def PerformanceRequirements;

    requirement <'R1'> reductionRatioRequirement : PerformanceRequirements {
        doc /* The reducer shall provide a speed reduction ratio between 6:1 and 87:1 */
        
        subject reducerSystem : EccentricReducer;
        
        require constraint {
            reducerSystem.reductionRatio >= 6.0 and
            reducerSystem.reductionRatio <= 87.0
        }
    }

    requirement <'R2'> efficiencyRequirement : PerformanceRequirements {
        doc /* The reducer shall maintain mechanical efficiency above 90% under rated load */
        
        subject reducerSystem : EccentricReducer;
        
        require constraint {
            reducerSystem.efficiency >= 0.90
        }
    }

    requirement <'R3'> torqueCapacityRequirement : PerformanceRequirements {
        doc /* The reducer shall transmit output torque proportional to reduction ratio with efficiency factor */
        
        subject reducerSystem : EccentricReducer;
        
        require constraint {
            reducerSystem.outputShaft.torque == 
            reducerSystem.inputShaft.torque * reducerSystem.reductionRatio * reducerSystem.efficiency
        }
    }

    requirement <'R4'> temperatureRequirement : PerformanceRequirements {
        doc /* The reducer operating temperature shall not exceed 80 degrees Celsius under continuous operation */
        
        subject reducerSystem : EccentricReducer;
        
        require constraint {
            reducerSystem.operatingTemp <= 353.15 [SI::K]
        }
    }

    requirement <'SYS-1'> primaryFunctionRequirement {
        doc /* 
        The eccentric reducer system shall convert high-speed, low-torque rotational input 
        into low-speed, high-torque rotational output through eccentric cycloidal motion.
        
        Primary Function: The system uses an eccentric disc mounted on the input shaft to 
        generate orbital motion of a cycloidal gear. This cycloidal gear meshes with pins 
        in the housing, converting the eccentric motion into reduced rotational speed at 
        the output shaft. The mechanism provides high reduction ratios in a compact form 
        with minimal backlash and high efficiency. The eccentric disc rotates about the 
        input shaft axis while simultaneously causing the cycloidal gear to orbit and rotate 
        at a much slower rate, thereby achieving speed reduction and torque multiplication.
        */
        
        assume constraint validInputConditions {
            eccentricReducerSystem.inputShaft.speed > 0.0 [SI::rad/SI::s] and
            eccentricReducerSystem.inputShaft.torque > 0.0 [SI::N*SI::m]
        }
        
        require reductionRatioRequirement;
        require efficiencyRequirement;
        require torqueCapacityRequirement;
        require temperatureRequirement;
    }
}
