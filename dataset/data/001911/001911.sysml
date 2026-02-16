package CuriosityRoverSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def PowerValue :> Real;
    attribute def DataRateValue :> Real;
    attribute def DistanceValue :> Real;
    attribute def TemperatureValue :> Real;

    enum def RoverMode {
        idle;
        navigating;
        sampling;
        analyzing;
        communicating;
        charging;
        fault;
    }

    enum def TerrainType {
        flat;
        rocky;
        sandy;
        slope;
    }

    item def RockSample {
        attribute mass : MassValue;
        attribute mineralComposition : String;
        attribute organicContent : Boolean;
        attribute collectionTimestamp : TimeValue;
    }

    item def ScienceData {
        attribute dataSize : Real;
        attribute dataType : String;
        attribute timestamp : TimeValue;
        attribute priority : Integer;
    }

    item def CommandSignal {
        attribute commandID : String;
        attribute parameters : String;
    }

    interface def PowerInterface {
        out item suppliedPower : PowerValue;
        in item requestedPower : PowerValue;
    }

    interface def DataInterface {
        in item command : CommandSignal;
        out item telemetry : ScienceData;
    }

    interface def ThermalInterface {
        in item heatLoad : PowerValue;
        out item rejectedHeat : PowerValue;
    }

    part def RadioisotopeThermoelectricGenerator {
        doc /* Multi-Mission Radioisotope Thermoelectric Generator (MMRTG) */
        attribute thermalPower : PowerValue = 2000.0;
        attribute electricalPower : PowerValue = 110.0;
        attribute efficiency : Real = 0.055;
        port powerOut : ~PowerInterface;
        port thermalOut : ~ThermalInterface;
    }

    part def BatteryPack {
        attribute capacity : Real = 42000.0;
        attribute voltage : Real = 28.0;
        attribute stateOfCharge : Real;
        attribute maxChargeRate : PowerValue = 50.0;
        port powerInOut : PowerInterface;
    }

    part def PowerSubsystem {
        attribute totalAvailablePower : PowerValue;
        attribute batteryLevel : Real;
        part rtg : RadioisotopeThermoelectricGenerator;
        part batteries : BatteryPack[2];
        port powerDistribution : ~PowerInterface;
        port thermalOutput : ~ThermalInterface;
    }

    part def WheelAssembly {
        attribute diameter : LengthValue = 0.5[m];
        attribute width : LengthValue = 0.4[m];
        attribute motorTorque : Real;
        attribute rotationSpeed : Real;
    }

    part def RockerBogieSystem {
        attribute articulationAngle : AngleValue;
        attribute suspensionTravel : LengthValue = 0.3[m];
        part wheels : WheelAssembly[6];
    }

    part def MobilitySubsystem {
        attribute maxSpeed : Real = 0.14;
        attribute currentSpeed : Real;
        attribute totalDistanceTraveled : DistanceValue;
        attribute powerConsumption : PowerValue;
        part suspension : RockerBogieSystem;
        port powerIn : PowerInterface;
        port navigationControl : DataInterface;
    }

    part def XBandAntenna {
        attribute gain : Real = 26.0;
        attribute frequency : Real = 8.4;
        attribute transmitPower : PowerValue = 15.0;
        attribute dataRate : DataRateValue;
    }

    part def UHFAntenna {
        attribute frequency : Real = 400.0;
        attribute dataRate : DataRateValue = 2000.0;
    }

    part def CommunicationSubsystem {
        attribute uplinkRate : DataRateValue = 32.0;
        attribute downlinkRate : DataRateValue = 250.0;
        attribute transmissionPower : PowerValue;
        part xBand : XBandAntenna;
        part uhf : UHFAntenna;
        port powerIn : PowerInterface;
        port dataIn : DataInterface;
    }

    part def MastCamera {
        attribute resolution : Real = 1600.0;
        attribute zoomFactor : Real = 10.0;
        attribute fieldOfView : AngleValue;
    }

    part def ChemCam {
        attribute laserPower : PowerValue = 14.0;
        attribute analysisRange : LengthValue = 7.0[m];
        attribute spectrometerChannels : Integer = 6144;
    }

    part def SampleAcquisitionDrill {
        attribute maxDrillDepth : LengthValue = 0.05[m];
        attribute drillDiameter : LengthValue = 0.016[m];
        attribute rotationSpeed : Real;
    }

    part def SampleAnalysisLaboratory {
        attribute ovenCount : Integer = 74;
        attribute maxTemperature : TemperatureValue = 1273.0;
        attribute gasAnalyzerChannels : Integer = 8;
    }

    part def ScienceInstrumentSuite {
        attribute operatingTemperature : TemperatureValue;
        attribute totalPowerDraw : PowerValue = 50.0;
        part mastcam : MastCamera;
        part chemcam : ChemCam;
        part drill : SampleAcquisitionDrill;
        part sam : SampleAnalysisLaboratory;
        port powerIn : PowerInterface;
        port dataOut : DataInterface;
        port thermalLoad : ThermalInterface;
    }

    part def HazardAvoidanceCameras {
        attribute count : Integer = 8;
        attribute fieldOfView : AngleValue;
    }

    part def InertialMeasurementUnit {
        attribute accelerometerRange : Real;
        attribute gyroscopeRange : Real;
        attribute updateRate : Real = 100.0;
    }

    part def NavigationSubsystem {
        attribute currentPosition : String;
        attribute targetWaypoint : String;
        attribute localizationAccuracy : LengthValue = 0.5[m];
        part hazcams : HazardAvoidanceCameras;
        part imu : InertialMeasurementUnit;
        port powerIn : PowerInterface;
        port sensorData : DataInterface;
        port mobilityCommand : ~DataInterface;
    }

    part def ThermalControlSubsystem {
        attribute internalTemperature : TemperatureValue;
        attribute targetTemperature : TemperatureValue = 273.0;
        attribute heaterPower : PowerValue;
        part heaters[8];
        part radiators[2];
        port powerIn : PowerInterface;
        port thermalManagement : ~ThermalInterface;
    }

    part def OnboardComputer {
        attribute cpuSpeed : Real = 200.0;
        attribute memoryCapacity : Real = 256.0;
        attribute storageCapacity : Real = 2000.0;
        port powerIn : PowerInterface;
        port systemBus : DataInterface;
    }

    action def NavigateToTarget {
        in targetLocation : String;
        in terrainType : TerrainType;
        out distanceTraveled : DistanceValue;
        out energyConsumed : PowerValue;
        out navigationSuccess : Boolean;
    }

    action def CollectRockSample {
        in targetLocation : String;
        in drillDepth : LengthValue;
        out sample : RockSample;
        out collectionSuccess : Boolean;
    }

    action def AnalyzeSample {
        in sample : RockSample;
        in analysisType : String;
        out scienceData : ScienceData;
        out analysisComplete : Boolean;
    }

    action def TransmitToEarth {
        in data : ScienceData;
        in targetStation : String;
        out transmissionSuccess : Boolean;
        out dataTransmitted : Real;
    }

    action def MonitorPowerStatus {
        out batteryCharge : Real;
        out powerGeneration : PowerValue;
        out powerConsumption : PowerValue;
    }

    action def MarsExplorationMission {
        first start;
        then merge missionLoop;

        then action checkPower : MonitorPowerStatus {
            out currentBattery : Real;
            out currentGeneration : PowerValue;
            out currentConsumption : PowerValue;
        }

        then decide;
            if checkPower.currentBattery < 25.0 then enterChargingMode;
            if checkPower.currentBattery >= 25.0 then continueMission;

        action enterChargingMode {
            doc /* Wait for RTG to recharge batteries to safe level */
        }
        then missionLoop;

        action continueMission;
        then action navigateToSite : NavigateToTarget {
            in targetLocation = "Gale Crater Target";
            in terrainType = TerrainType::rocky;
            out travelDistance : DistanceValue;
            out energyUsed : PowerValue;
            out navSuccess : Boolean;
        }

        then decide;
            if navigateToSite.navSuccess then proceedToSampling;
            if !navigateToSite.navSuccess then missionLoop;

        action proceedToSampling;
        then action collectSample : CollectRockSample {
            in targetLocation = navigateToSite.targetLocation;
            in drillDepth = 0.05[m];
            out rockSample : RockSample;
            out success : Boolean;
        }

        then decide;
            if collectSample.success then performAnalysis;
            if !collectSample.success then missionLoop;

        action performAnalysis : AnalyzeSample {
            in sample = collectSample.rockSample;
            in analysisType = "mineralogy";
            out results : ScienceData;
            out complete : Boolean;
        }

        then action transmitResults : TransmitToEarth {
            in data = performAnalysis.results;
            in targetStation = "Deep Space Network";
            out txSuccess : Boolean;
            out dataSent : Real;
        }

        then missionLoop;
    }

    state def RoverOperationalStateMachine {
        entry; then idle;

        state idle {
            entry assign currentMode = RoverMode::idle;
        }
        transition idle_to_navigating
            first idle
            accept ReceiveNavigationCommand
            then navigating;

        state navigating {
            entry assign currentMode = RoverMode::navigating;
        }
        transition navigating_to_sampling
            first navigating
            if arrivedAtTarget
            then sampling;

        state sampling {
            entry assign currentMode = RoverMode::sampling;
        }
        transition sampling_to_analyzing
            first sampling
            if sampleAcquired
            then analyzing;

        state analyzing {
            entry assign currentMode = RoverMode::analyzing;
        }
        transition analyzing_to_communicating
            first analyzing
            if analysisCompleted
            then communicating;

        state communicating {
            entry assign currentMode = RoverMode::communicating;
        }
        transition communicating_to_idle
            first communicating
            if dataTransmitted
            then idle;

        transition any_to_charging
            accept LowBatteryDetected
            then charging;

        state charging {
            entry assign currentMode = RoverMode::charging;
        }
        transition charging_to_idle
            first charging
            if batteryChargeSufficient
            then idle;

        transition any_to_fault
            accept SystemFaultDetected
            then fault;

        state fault {
            entry assign currentMode = RoverMode::fault;
        }
        transition fault_to_idle
            first fault
            accept FaultCleared
            then idle;
    }

    part def CuriosityRover {
        doc /* Mars Science Laboratory rover designed to explore Gale Crater 
             * and assess past habitability conditions on Mars. */

        attribute totalMass : MassValue = 899.0[kg];
        attribute operationalLifetime : TimeValue;
        attribute currentMode : RoverMode;
        attribute missionObjective : String = "Assess past habitability of Mars";

        part power : PowerSubsystem;
        part mobility : MobilitySubsystem;
        part communication : CommunicationSubsystem;
        part science : ScienceInstrumentSuite;
        part navigation : NavigationSubsystem;
        part thermal : ThermalControlSubsystem;
        part computer : OnboardComputer;

        connection powerToMobility connect power.powerDistribution to mobility.powerIn;
        connection powerToScience connect power.powerDistribution to science.powerIn;
        connection powerToCommunication connect power.powerDistribution to communication.powerIn;
        connection powerToNavigation connect power.powerDistribution to navigation.powerIn;
        connection powerToThermal connect power.powerDistribution to thermal.powerIn;
        connection powerToComputer connect power.powerDistribution to computer.powerIn;

        connection navigationToMobility connect navigation.mobilityCommand to mobility.navigationControl;
        connection scienceToCommunication connect science.dataOut to communication.dataIn;
        connection thermalFromPower connect power.thermalOutput to thermal.thermalManagement;
        connection thermalFromScience connect science.thermalLoad to thermal.thermalManagement;

        perform action mission : MarsExplorationMission;
        exhibit state operations : RoverOperationalStateMachine;
    }

    requirement <'MSL-REQ-001'> missionObjective {
        doc /* The Curiosity rover shall explore the Martian surface to determine 
             * whether Mars ever offered environmental conditions favorable for 
             * microbial life, including investigation of the chemical composition 
             * of rocks and soil. */
        subject rover : CuriosityRover;
    }

    requirement <'MSL-REQ-002'> mobilityCapability {
        doc /* The rover shall traverse rocky Martian terrain and travel up to 
             * 200 meters per Martian sol with obstacle avoidance capability. */
        subject mobility :>> CuriosityRover::mobility;
        assert constraint {
            mobility.maxSpeed >= 0.14
        }
    }

    requirement <'MSL-REQ-003'> powerGeneration {
        doc /* The rover shall generate continuous electrical power using a 
             * radioisotope thermoelectric generator providing at least 110 watts 
             * to enable multi-year operations independent of solar availability. */
        subject power :>> CuriosityRover::power;
        assert constraint {
            power.rtg.electricalPower >= 110.0
        }
    }

    requirement <'MSL-REQ-004'> sampleAnalysis {
        doc /* The rover shall collect, process, and analyze rock and soil samples 
             * using onboard instruments to determine mineralogical composition and 
             * detect organic compounds. */
        subject science :>> CuriosityRover::science;
    }

    requirement <'MSL-REQ-005'> dataTransmission {
        doc /* The rover shall transmit scientific data to Earth via X-band direct 
             * communication or UHF relay through Mars orbiters at rates sufficient 
             * for mission science return. */
        subject comm :>> CuriosityRover::communication;
        assert constraint {
            comm.downlinkRate >= 250.0
        }
    }

    requirement <'MSL-REQ-006'> massConstraint {
        doc /* The total rover mass shall not exceed 900 kg to meet entry, descent, 
             * and landing system constraints. */
        subject rover :>> curiosityRover;
        assert constraint {
            rover.totalMass <= 900.0[kg]
        }
    }

    requirement <'MSL-REQ-007'> thermalControl {
        doc /* The rover shall maintain internal temperature within operational 
             * limits despite extreme Martian temperature variations. */
        subject thermal :>> CuriosityRover::thermal;
        assert constraint {
            thermal.targetTemperature == 273.0
        }
    }

    part curiosityRover : CuriosityRover;

    satisfy missionObjective by curiosityRover;
    satisfy mobilityCapability by curiosityRover.mobility;
    satisfy powerGeneration by curiosityRover.power;
    satisfy sampleAnalysis by curiosityRover.science;
    satisfy dataTransmission by curiosityRover.communication;
    satisfy massConstraint by curiosityRover;
    satisfy thermalControl by curiosityRover.thermal;
}
