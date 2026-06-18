package GerotorBasedHydraulicPumpSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def PressureValue :> Real {
        doc /* Pressure of hydraulic fluid. Unit: kilopascal. */
    }

    attribute def VolumetricFlowRateValue :> Real {
        doc /* Volumetric flow rate. Unit: liter per minute. */
    }

    attribute def RotationalSpeedValue :> Real {
        doc /* Rotational speed. Unit: revolution per minute. */
    }

    attribute def TorqueValue :> Real {
        doc /* Mechanical torque. Unit: newton meter. */
    }

    attribute def TemperatureValue :> Real {
        doc /* Temperature. Unit: degree Celsius. */
    }

    attribute def VolumeValue :> Real {
        doc /* Volume. Unit: cubic centimeter. */
    }

    attribute def EfficiencyValue :> Real {
        doc /* Ratio from 0.0 to 1.0. */
    }

    attribute def PowerValue :> Real {
        doc /* Power. Unit: watt. */
    }

    attribute def TimeValue :> Real {
        doc /* Time. Unit: second. */
    }

    item def HydraulicOil {
        attribute density : Real = 860.0;
        attribute dynamicViscosity : Real = 0.046;
        attribute temperature : TemperatureValue = 40.0;
        attribute contaminationCode : String = "ISO 4406 18/16/13";
        attribute bulkModulus : PressureValue = 1500000.0;
    }

    item def LowPressureHydraulicOil :> HydraulicOil {
        attribute pressure : PressureValue = 100.0;
    }

    item def PressurizedHydraulicOil :> HydraulicOil {
        attribute pressure : PressureValue;
        attribute flowRate : VolumetricFlowRateValue;
    }

    item def MechanicalRotation {
        attribute speed : RotationalSpeedValue;
        attribute torque : TorqueValue;
        attribute direction : String = "clockwise viewed from drive end";
    }

    item def ControlSignal {
        attribute enable : Boolean;
        attribute commandedSpeed : RotationalSpeedValue;
        attribute commandedPressureLimit : PressureValue;
    }

    item def StatusSignal {
        attribute running : Boolean;
        attribute primed : Boolean;
        attribute faultActive : Boolean;
        attribute measuredOutletPressure : PressureValue;
        attribute measuredFlowRate : VolumetricFlowRateValue;
        attribute measuredSpeed : RotationalSpeedValue;
        attribute measuredTemperature : TemperatureValue;
    }

    port def HydraulicInletPort {
        in item fluidIn : LowPressureHydraulicOil;
        attribute nominalPressure : PressureValue = 100.0;
        attribute maximumVacuum : PressureValue = -30.0;
    }

    port def HydraulicOutletPort {
        out item fluidOut : PressurizedHydraulicOil;
        attribute ratedPressure : PressureValue = 16000.0;
        attribute reliefPressure : PressureValue = 17500.0;
    }

    port def InternalHydraulicPort {
        inout item fluid : HydraulicOil;
        attribute localPressure : PressureValue;
        attribute localFlowRate : VolumetricFlowRateValue;
    }

    port def ShaftInputPort {
        in item rotationIn : MechanicalRotation;
        attribute ratedSpeed : RotationalSpeedValue = 3000.0;
        attribute ratedTorque : TorqueValue = 42.0;
    }

    port def ElectricalControlPort {
        in item command : ControlSignal;
    }

    port def ElectricalStatusPort {
        out item status : StatusSignal;
    }

    port def ThermalPort {
        out item heatFlow : PowerValue;
        attribute surfaceTemperature : TemperatureValue;
    }

    port def DrainPort {
        out item leakageOil : HydraulicOil;
        attribute leakageFlow : VolumetricFlowRateValue;
    }

    part def GerotorInnerRotor {
        attribute toothCount : Integer = 6;
        attribute outsideDiameter : Real = 54.0;
        attribute faceWidth : Real = 18.0;
        attribute eccentricity : Real = 2.8;
        attribute material : String = "hardened nitrided steel";
        attribute surfaceHardness : String = "58 HRC";
        port driveHub : ShaftInputPort;
        port chamberInterface : InternalHydraulicPort;
    }

    part def GerotorOuterRotor {
        attribute toothCount : Integer = 7;
        attribute outsideDiameter : Real = 72.0;
        attribute faceWidth : Real = 18.0;
        attribute material : String = "sintered alloy steel";
        attribute surfaceHardness : String = "55 HRC";
        port chamberInterface : InternalHydraulicPort;
    }

    part def PumpHousing {
        attribute material : String = "cast aluminum alloy";
        attribute maximumWorkingPressure : PressureValue = 21000.0;
        attribute oilVolume : VolumeValue = 95.0;
        attribute inletPortDiameter : Real = 18.0;
        attribute outletPortDiameter : Real = 12.0;
        port inletGallery : InternalHydraulicPort;
        port outletGallery : InternalHydraulicPort;
        port caseDrain : DrainPort;
        port thermalInterface : ThermalPort;
    }

    part def CrescentChamberSet {
        attribute numberOfExpandingChambers : Integer = 3;
        attribute numberOfContractingChambers : Integer = 3;
        attribute nominalDisplacementPerRev : VolumeValue = 12.0;
        attribute volumetricEfficiency : EfficiencyValue = 0.91;
        attribute mechanicalEfficiency : EfficiencyValue = 0.86;
        port suctionSide : InternalHydraulicPort;
        port dischargeSide : InternalHydraulicPort;
        port innerRotorContact : InternalHydraulicPort;
        port outerRotorContact : InternalHydraulicPort;
    }

    part def DriveShaft {
        attribute diameter : Real = 16.0;
        attribute material : String = "42CrMo4 steel";
        attribute maximumContinuousTorque : TorqueValue = 55.0;
        attribute torsionalStiffness : Real = 1450.0;
        port mechanicalInput : ShaftInputPort;
        port rotorDrive : ShaftInputPort;
    }

    part def InletScreen {
        attribute meshSize : Real = 150.0;
        attribute pressureDropAtRatedFlow : PressureValue = 12.0;
        attribute retainedParticleSize : Real = 100.0;
        port upstream : HydraulicInletPort;
        port downstream : InternalHydraulicPort;
    }

    part def OutletCheckValve {
        attribute crackingPressure : PressureValue = 35.0;
        attribute maximumReverseLeakage : VolumetricFlowRateValue = 0.05;
        port inlet : InternalHydraulicPort;
        port outlet : HydraulicOutletPort;
    }

    part def PressureReliefValve {
        attribute setPressure : PressureValue = 17500.0;
        attribute reseatPressure : PressureValue = 16000.0;
        attribute maximumBypassFlow : VolumetricFlowRateValue = 42.0;
        attribute responseTime : TimeValue = 0.025;
        port highPressureSide : InternalHydraulicPort;
        port bypassReturn : InternalHydraulicPort;
    }

    part def ShaftSeal {
        attribute sealType : String = "spring-loaded radial lip seal";
        attribute maximumCasePressure : PressureValue = 250.0;
        attribute allowableLeakageFlow : VolumetricFlowRateValue = 0.03;
        port drain : DrainPort;
    }

    part def SpeedSensor {
        attribute sensingPrinciple : String = "magnetoresistive tooth detection";
        attribute measurementRange : RotationalSpeedValue = 6000.0;
        attribute accuracyPercent : Real = 1.0;
        port statusOut : ElectricalStatusPort;
    }

    part def PressureSensor {
        attribute range : PressureValue = 25000.0;
        attribute accuracyPercentFullScale : Real = 0.5;
        attribute responseTime : TimeValue = 0.005;
        port statusOut : ElectricalStatusPort;
        port sensedHydraulicPort : InternalHydraulicPort;
    }

    part def TemperatureSensor {
        attribute rangeLow : TemperatureValue = -40.0;
        attribute rangeHigh : TemperatureValue = 150.0;
        attribute accuracy : TemperatureValue = 2.0;
        port statusOut : ElectricalStatusPort;
    }

    action def DrawFluidIntoExpandingChambers {
        in item inletOil : LowPressureHydraulicOil;
        in attribute rotorSpeed : RotationalSpeedValue;
        out item chamberOil : HydraulicOil;
        out attribute inletFlow : VolumetricFlowRateValue;
        doc /* Expanding gerotor tooth volumes create suction and fill the chambers from the inlet gallery. */
    }

    action def TrapAndTransportFluid {
        in item chamberOil : HydraulicOil;
        in attribute innerRotorTeeth : Integer;
        in attribute outerRotorTeeth : Integer;
        out item transportedOil : HydraulicOil;
        doc /* Sealed fluid pockets are carried around the crescent region between inner and outer rotor teeth. */
    }

    action def CompressAndDischargeFluid {
        in item transportedOil : HydraulicOil;
        in attribute displacementPerRev : VolumeValue;
        in attribute rotorSpeed : RotationalSpeedValue;
        in attribute pressureLimit : PressureValue;
        out item outletOil : PressurizedHydraulicOil;
        out attribute deliveredFlow : VolumetricFlowRateValue;
        out attribute outletPressure : PressureValue;
        doc /* Contracting gerotor tooth volumes reduce chamber volume and force pressurized oil through the outlet gallery. */
    }

    action def LimitOutletPressure {
        in item highPressureOil : PressurizedHydraulicOil;
        in attribute measuredPressure : PressureValue;
        in attribute reliefSetPressure : PressureValue;
        out item bypassOil : HydraulicOil;
        out attribute reliefOpen : Boolean;
        doc /* Opens bypass path from outlet gallery to inlet gallery when pressure exceeds the calibrated relief setting. */
    }

    action def EstimateGerotorPerformance {
        in attribute rotorSpeed : RotationalSpeedValue;
        in attribute displacementPerRev : VolumeValue;
        in attribute volumetricEfficiency : EfficiencyValue;
        in attribute outletPressure : PressureValue;
        in attribute inletPressure : PressureValue;
        out attribute theoreticalFlow : VolumetricFlowRateValue;
        out attribute deliveredFlow : VolumetricFlowRateValue;
        out attribute hydraulicPower : PowerValue;
        out attribute inputTorque : TorqueValue;
    }

    action def OperateGerotorHydraulicPump {
        in item rotation : MechanicalRotation;
        in item inletOil : LowPressureHydraulicOil;
        in item command : ControlSignal;
        out item outletOil : PressurizedHydraulicOil;
        out item status : StatusSignal;

        action draw : DrawFluidIntoExpandingChambers {
            in item inletOil = inletOil;
            in attribute rotorSpeed = rotation.speed;
        }

        then action transport : TrapAndTransportFluid {
            in item chamberOil = draw.chamberOil;
            in attribute innerRotorTeeth = 6;
            in attribute outerRotorTeeth = 7;
        }

        then action discharge : CompressAndDischargeFluid {
            in item transportedOil = transport.transportedOil;
            in attribute displacementPerRev = 12.0;
            in attribute rotorSpeed = rotation.speed;
            in attribute pressureLimit = command.commandedPressureLimit;
        }

        then action relief : LimitOutletPressure {
            in item highPressureOil = discharge.outletOil;
            in attribute measuredPressure = discharge.outletPressure;
            in attribute reliefSetPressure = command.commandedPressureLimit;
        }

        then action performance : EstimateGerotorPerformance {
            in attribute rotorSpeed = rotation.speed;
            in attribute displacementPerRev = 12.0;
            in attribute volumetricEfficiency = 0.91;
            in attribute outletPressure = discharge.outletPressure;
            in attribute inletPressure = 100.0;
        }
    }

    state def GerotorPumpLifecycle {
        in item command : ControlSignal;
        in item rotation : MechanicalRotation;
        in attribute outletPressure : PressureValue;
        in attribute oilTemperature : TemperatureValue;

        state Off {
            entry action {
                send StatusSignal {
                    running = false;
                    primed = false;
                    faultActive = false;
                    measuredOutletPressure = 0.0;
                    measuredFlowRate = 0.0;
                    measuredSpeed = 0.0;
                    measuredTemperature = oilTemperature;
                }
            }
        }

        state Priming {
            entry action DrawFluidIntoExpandingChambers;
        }

        state Pumping {
            entry action OperateGerotorHydraulicPump;
        }

        state ReliefBypass {
            entry action LimitOutletPressure;
        }

        state Faulted {
            entry action {
                send StatusSignal {
                    running = false;
                    primed = false;
                    faultActive = true;
                    measuredOutletPressure = outletPressure;
                    measuredFlowRate = 0.0;
                    measuredSpeed = rotation.speed;
                    measuredTemperature = oilTemperature;
                }
            }
        }

        transition initialTransition first Off;

        transition startPriming
            first Off
            accept command
            if command.enable and rotation.speed > 200.0
            then Priming;

        transition primedToPumping
            first Priming
            if rotation.speed >= 600.0
            then Pumping;

        transition pumpToRelief
            first Pumping
            if outletPressure >= command.commandedPressureLimit
            then ReliefBypass;

        transition reliefToPump
            first ReliefBypass
            if outletPressure < command.commandedPressureLimit - 1500.0
            then Pumping;

        transition stopCommand
            first Pumping
            accept command
            if not command.enable
            then Off;

        transition overspeedFault
            first Pumping
            if rotation.speed > 3600.0
            then Faulted;

        transition overtemperatureFault
            first Pumping
            if oilTemperature > 120.0
            then Faulted;

        transition resetFault
            first Faulted
            accept command
            if not command.enable and rotation.speed < 50.0
            then Off;
    }

    part def GerotorHydraulicPowerUnit {
        doc /* A gerotor-based hydraulic pump system whose primary function is to convert rotary mechanical input into a continuous pressurized hydraulic oil flow using meshing inner and outer rotors with one-tooth-count difference. */

        attribute nominalDisplacementPerRevolution : VolumeValue = 12.0;
        attribute ratedSpeed : RotationalSpeedValue = 3000.0;
        attribute minimumPrimingSpeed : RotationalSpeedValue = 600.0;
        attribute ratedOutletPressure : PressureValue = 16000.0;
        attribute reliefPressure : PressureValue = 17500.0;
        attribute ratedFlow : VolumetricFlowRateValue = 32.8;
        attribute ratedInputTorque : TorqueValue = 38.0;
        attribute maximumOilTemperature : TemperatureValue = 120.0;
        attribute minimumOilTemperature : TemperatureValue = -20.0;
        attribute volumetricEfficiencyAtRatedCondition : EfficiencyValue = 0.91;
        attribute mechanicalEfficiencyAtRatedCondition : EfficiencyValue = 0.86;

        port suctionPort : HydraulicInletPort;
        port pressurePort : HydraulicOutletPort;
        port shaftPort : ShaftInputPort;
        port controlPort : ElectricalControlPort;
        port statusPort : ElectricalStatusPort;
        port caseDrainPort : DrainPort;
        port heatPort : ThermalPort;

        part housing : PumpHousing;
        part shaft : DriveShaft;
        part innerRotor : GerotorInnerRotor;
        part outerRotor : GerotorOuterRotor;
        part chambers : CrescentChamberSet;
        part inletScreen : InletScreen;
        part checkValve : OutletCheckValve;
        part reliefValve : PressureReliefValve;
        part shaftSeal : ShaftSeal;
        part speedSensor : SpeedSensor;
        part pressureSensor : PressureSensor;
        part temperatureSensor : TemperatureSensor;

        connection suctionToScreen
            connect suctionPort to inletScreen.upstream;

        connection screenToInletGallery
            connect inletScreen.downstream to housing.inletGallery;

        connection inletGalleryToChambers
            connect housing.inletGallery to chambers.suctionSide;

        connection shaftToRotorDrive
            connect shaftPort to shaft.mechanicalInput;

        connection shaftOutputToInnerRotor
            connect shaft.rotorDrive to innerRotor.driveHub;

        connection innerRotorToChambers
            connect innerRotor.chamberInterface to chambers.innerRotorContact;

        connection outerRotorToChambers
            connect outerRotor.chamberInterface to chambers.outerRotorContact;

        connection chambersToOutletGallery
            connect chambers.dischargeSide to housing.outletGallery;

        connection outletGalleryToCheckValve
            connect housing.outletGallery to checkValve.inlet;

        connection checkValveToPressurePort
            connect checkValve.outlet to pressurePort;

        connection outletGalleryToReliefValve
            connect housing.outletGallery to reliefValve.highPressureSide;

        connection reliefValveToInletGallery
            connect reliefValve.bypassReturn to housing.inletGallery;

        connection housingDrainToExternalDrain
            connect housing.caseDrain to caseDrainPort;

        connection sealDrainToExternalDrain
            connect shaftSeal.drain to caseDrainPort;

        connection housingThermalToExternalThermal
            connect housing.thermalInterface to heatPort;

        connection outletGalleryToPressureSensor
            connect housing.outletGallery to pressureSensor.sensedHydraulicPort;

        connection pressureStatusToSystemStatus
            connect pressureSensor.statusOut to statusPort;

        connection speedStatusToSystemStatus
            connect speedSensor.statusOut to statusPort;

        connection temperatureStatusToSystemStatus
            connect temperatureSensor.statusOut to statusPort;

        perform action operation : OperateGerotorHydraulicPump {
            in item rotation = shaftPort.rotationIn;
            in item inletOil = suctionPort.fluidIn;
            in item command = controlPort.command;
            out item outletOil = pressurePort.fluidOut;
            out item status = statusPort.status;
        }

        exhibit state lifecycle : GerotorPumpLifecycle;
    }

    requirement def PrimaryGerotorFunctionRequirement {
        doc /* The system shall convert continuous rotary mechanical input into continuous pressurized hydraulic fluid flow by the gerotor pumping principle. */
        subject pump : GerotorHydraulicPowerUnit;

        require constraint {
            pump.nominalDisplacementPerRevolution == 12.0 and
            pump.ratedSpeed == 3000.0 and
            pump.ratedFlow >= 30.0 and
            pump.ratedOutletPressure >= 16000.0
        }
    }

    requirement def GerotorGeometryRequirement {
        doc /* The inner and outer rotors shall form a gerotor pair with the outer rotor having exactly one more tooth than the inner rotor to create expanding and contracting sealed chambers. */
        subject pump : GerotorHydraulicPowerUnit;

        require constraint {
            pump.innerRotor.toothCount == 6 and
            pump.outerRotor.toothCount == 7 and
            pump.outerRotor.toothCount == pump.innerRotor.toothCount + 1
        }
    }

    requirement def PressureReliefRequirement {
        doc /* The pump shall protect itself and downstream equipment by bypassing outlet flow to the inlet gallery when outlet pressure exceeds the relief setting. */
        subject pump : GerotorHydraulicPowerUnit;

        require constraint {
            pump.reliefValve.setPressure == 17500.0 and
            pump.reliefValve.responseTime <= 0.050 and
            pump.reliefValve.maximumBypassFlow >= pump.ratedFlow
        }
    }

    requirement def PrimingRequirement {
        doc /* The pump shall establish suction and fill the gerotor chambers when enabled and driven above the minimum priming speed. */
        subject pump : GerotorHydraulicPowerUnit;

        require constraint {
            pump.minimumPrimingSpeed <= 600.0 and
            pump.inletScreen.pressureDropAtRatedFlow <= 20.0
        }
    }

    requirement def LeakageRequirement {
        doc /* Case and shaft-seal leakage shall remain small relative to rated delivery flow during normal operation. */
        subject pump : GerotorHydraulicPowerUnit;

        require constraint {
            pump.shaftSeal.allowableLeakageFlow <= 0.03 and
            pump.shaftSeal.maximumCasePressure >= 250.0
        }
    }

    requirement def ThermalOperatingRequirement {
        doc /* The pump shall operate without fault while oil temperature is within the specified operating range and shall enter fault state above the maximum oil temperature. */
        subject pump : GerotorHydraulicPowerUnit;

        require constraint {
            pump.minimumOilTemperature <= -20.0 and
            pump.maximumOilTemperature == 120.0
        }
    }

    part gerotorPumpSystem : GerotorHydraulicPowerUnit {
        attribute nominalDisplacementPerRevolution = 12.0;
        attribute ratedSpeed = 3000.0;
        attribute ratedOutletPressure = 16000.0;
        attribute reliefPressure = 17500.0;
        attribute ratedFlow = 32.8;
    }

    satisfy PrimaryGerotorFunctionRequirement by gerotorPumpSystem;
    satisfy GerotorGeometryRequirement by gerotorPumpSystem;
    satisfy PressureReliefRequirement by gerotorPumpSystem;
    satisfy PrimingRequirement by gerotorPumpSystem;
    satisfy LeakageRequirement by gerotorPumpSystem;
    satisfy ThermalOperatingRequirement by gerotorPumpSystem;
}
