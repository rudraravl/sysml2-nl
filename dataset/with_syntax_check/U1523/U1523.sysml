package WaterAerationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def OxygenConcentration :> ISQ::MassConcentrationValue;
    
    attribute def AirFlowRate :> ISQ::VolumeFlowRateValue;
    attribute def WaterFlowRate :> ISQ::VolumeFlowRateValue;
    attribute def MotorSpeed :> ISQ::AngularVelocityValue;
    
    item def CompressedAir;
    item def Water;
    item def OxygenatedWater;
    item def ControlSignal {
        attribute commandedSpeed : MotorSpeed;
        attribute enable : Boolean;
    }
    item def SensorData {
        attribute dissolvedOxygen : OxygenConcentration;
        attribute timestamp : Real;
    }
    
    port def WaterInletPort {
        in item waterIn : Water;
        attribute flowRate : WaterFlowRate;
        attribute inletDO : OxygenConcentration;
    }
    
    port def WaterOutletPort {
        out item waterOut : OxygenatedWater;
        attribute flowRate : WaterFlowRate;
        attribute outletDO : OxygenConcentration;
    }
    
    port def AirSupplyPort {
        out item airOut : CompressedAir;
        attribute flowRate : AirFlowRate;
        attribute pressure : ISQ::PressureValue;
    }
    
    port def SensorPort {
        out item sensorReading : SensorData;
    }
    
    port def ControlPort {
        in item controlCmd : ControlSignal;
    }
    
    action def DeliverCompressedAir {
        in atmosphericAir : Real;
        in motorSpeed : MotorSpeed;
        out compressedAir : AirFlowRate;
        out airPressure : ISQ::PressureValue;
    }
    
    action def DisperseAirIntoBubbles {
        in compressedAir : AirFlowRate;
        in pressure : ISQ::PressureValue;
        out bubbleCount : Real;
        out surfaceArea : ISQ::AreaValue;
    }
    
    action def TransferOxygenToWater {
        in bubbleSurfaceArea : ISQ::AreaValue;
        in waterVolume : ISQ::VolumeValue;
        in currentDO : OxygenConcentration;
        in contactTime : ISQ::TimeValue;
        out enhancedDO : OxygenConcentration;
    }
    
    action def MeasureDissolvedOxygen {
        in waterSample : Water;
        out measurement : OxygenConcentration;
        out timestamp : Real;
    }
    
    action def ControlAerationProcess {
        in currentDO : OxygenConcentration;
        in targetDO : OxygenConcentration;
        out speedCommand : MotorSpeed;
        out enableCommand : Boolean;
    }
    
    part def AirBlower {
        doc /* Compresses atmospheric air and delivers it at controlled flow rate */
        
        port airOutput : AirSupplyPort;
        port motorControl : ControlPort;
        
        attribute maxFlowRate : AirFlowRate;
        attribute maxPressure : ISQ::PressureValue;
        attribute currentSpeed : MotorSpeed;
        
        perform action deliverAir : DeliverCompressedAir;
    }
    
    part def DiffuserGrid {
        doc /* Disperses compressed air into fine bubbles throughout water volume */
        
        port airInput {
            in item airIn : CompressedAir;
            attribute flowRate : AirFlowRate;
        }
        
        attribute numberOfDiffusers : Integer;
        attribute bubbleDiameter : ISQ::LengthValue;
        attribute distributionEfficiency : Real;
        
        perform action disperseAir : DisperseAirIntoBubbles;
    }
    
    part def AerationChamber {
        doc /* Contains water volume where oxygen transfer occurs */
        
        port waterInlet : WaterInletPort;
        port waterOutlet : WaterOutletPort;
        port airInlet {
            in item airIn : CompressedAir;
        }
        
        attribute chamberVolume : ISQ::VolumeValue;
        attribute retentionTime : ISQ::TimeValue;
        attribute currentDO : OxygenConcentration;
        
        part diffuserGrid : DiffuserGrid[1];
        
        perform action transferOxygen : TransferOxygenToWater;
    }
    
    part def DissolvedOxygenSensor {
        doc /* Measures dissolved oxygen concentration in water */
        
        port measurementPoint {
            in item waterSample : Water;
        }
        port dataOutput : SensorPort;
        
        attribute measurementRange : OxygenConcentration[2];
        attribute accuracy : Real;
        attribute responseTime : ISQ::TimeValue;
        
        perform action measureDO : MeasureDissolvedOxygen;
    }
    
    part def AerationController {
        doc /* Controls blower operation based on dissolved oxygen feedback */
        
        port sensorInput {
            in item sensorData : SensorData;
        }
        port blowerControl {
            out item controlSignal : ControlSignal;
        }
        
        attribute setpoint : OxygenConcentration;
        attribute lowThreshold : OxygenConcentration;
        attribute highThreshold : OxygenConcentration;
        attribute proportionalGain : Real;
        
        perform action controlAeration : ControlAerationProcess;
    }
    
    action def PerformAeration {
        doc /* Primary aeration process coordinating all subsystem actions */
        
        in waterInflowRate : WaterFlowRate;
        in inletDOLevel : OxygenConcentration;
        in targetDOLevel : OxygenConcentration;
        out waterOutflowRate : WaterFlowRate;
        out outletDOLevel : OxygenConcentration;
        
        first start;
        then merge continuousOperation;
        
        action sense : MeasureDissolvedOxygen {
            in waterSample;
            out measurement;
            out timestamp;
        }
        
        flow sense.measurement to control.currentDO;
        
        action control : ControlAerationProcess {
            in currentDO;
            in targetDO = targetDOLevel;
            out speedCommand;
            out enableCommand;
        }
        
        flow control.speedCommand to compress.motorSpeed;
        
        action compress : DeliverCompressedAir {
            in atmosphericAir = 1.0;
            in motorSpeed;
            out compressedAir;
            out airPressure;
        }
        
        flow compress.compressedAir to disperse.compressedAir;
        flow compress.airPressure to disperse.pressure;
        
        action disperse : DisperseAirIntoBubbles {
            in compressedAir;
            in pressure;
            out bubbleCount;
            out surfaceArea;
        }
        
        flow disperse.surfaceArea to transfer.bubbleSurfaceArea;
        
        action transfer : TransferOxygenToWater {
            in bubbleSurfaceArea;
            in waterVolume = 1000.0 [SI::L];
            in currentDO = sense.measurement;
            in contactTime = 30.0 [SI::s];
            out enhancedDO;
        }
        
        then assign outletDOLevel := transfer.enhancedDO;
        then assign waterOutflowRate := waterInflowRate;
        
        then decide;
            if transfer.enhancedDO.num < targetDOLevel.num then continuousOperation;
            if transfer.enhancedDO.num >= targetDOLevel.num then done;
    }
    
    part def WaterAerationSystem {
        doc /* 
            A water aeration system that increases dissolved oxygen concentration 
            in water by introducing compressed air through diffusers. The system 
            continuously monitors oxygen levels and automatically adjusts air flow 
            to maintain target dissolved oxygen concentration for water quality 
            management in applications such as wastewater treatment, aquaculture, 
            and industrial processes.
        */
        
        port waterInlet : WaterInletPort;
        port waterOutlet : WaterOutletPort;
        
        attribute operatingVolume : ISQ::VolumeValue = 5000.0 [SI::L];
        attribute targetDO : OxygenConcentration = 8.0 [SI::kg/SI::m^3];
        attribute minimumDO : OxygenConcentration = 6.0 [SI::kg/SI::m^3];
        attribute maximumDO : OxygenConcentration = 10.0 [SI::kg/SI::m^3];
        
        part blower : AirBlower {
            :>> maxFlowRate = 500.0 [SI::L/SI::min];
            :>> maxPressure = 50.0 [SI::kPa];
        }
        
        part chamber : AerationChamber {
            :>> chamberVolume = operatingVolume;
            :>> retentionTime = 45.0 [SI::min];
        }
        
        part sensor : DissolvedOxygenSensor {
            :>> accuracy = 0.1;
            :>> responseTime = 5.0 [SI::s];
        }
        
        part controller : AerationController {
            :>> setpoint = targetDO;
            :>> lowThreshold = minimumDO;
            :>> highThreshold = maximumDO;
            :>> proportionalGain = 0.5;
        }
        
        connect blower.airOutput to chamber.airInlet;
        connect chamber.diffuserGrid.airInput to chamber.airInlet;
        connect sensor.measurementPoint to chamber.waterOutlet;
        connect sensor.dataOutput to controller.sensorInput;
        connect controller.blowerControl to blower.motorControl;
        
        perform action aerationOperation : PerformAeration {
            in targetDOLevel = targetDO;
        }
    }
    
    part aerationSystem : WaterAerationSystem;
    
    requirement def OxygenTransferRequirement {
        doc /* The system shall transfer oxygen to water to achieve target dissolved oxygen concentration */
        
        subject system : WaterAerationSystem;
        require constraint {
            system.chamber.currentDO.num >= system.minimumDO.num
        }
    }
    
    requirement def ContinuousOperationRequirement {
        doc /* The system shall operate continuously to maintain dissolved oxygen levels */
        
        subject system : WaterAerationSystem;
    }
    
    requirement def EnergyEfficiencyRequirement {
        doc /* The system shall minimize energy consumption by operating blower only when necessary */
        
        subject controller : AerationController;
    }
    
    requirement def MeasurementAccuracyRequirement {
        doc /* Dissolved oxygen measurements shall be accurate within specified tolerance */
        
        subject sensor : DissolvedOxygenSensor;
        require constraint {
            sensor.accuracy <= 0.2
        }
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for water aeration system */
        
        subject aerationSystem : WaterAerationSystem;
        
        require oxygenTransfer : OxygenTransferRequirement;
        require continuousOp : ContinuousOperationRequirement;
        require energyEfficiency : EnergyEfficiencyRequirement;
        require measurementAccuracy : MeasurementAccuracyRequirement;
    }
}
