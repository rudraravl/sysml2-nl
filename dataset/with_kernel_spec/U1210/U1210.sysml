package SmartElectricalGrid {
    private import ISQ::*;
    private import ScalarValues::*;
    private import SI::*;
    
    enum def GridState {
        stable;
        overloaded;
        underloaded;
        critical;
    }

    enum def PriorityLevel {
        critical;
        high;
        low;
    }

    enum def ControlAction {
        optimize;
        discharge;
        charge;
        rampDown;
        shedLoad;
        emergency;
    }

    item def MeterReading {
        attribute demand : power;
        attribute priority : PriorityLevel;
    }

    item def GenerationData {
        attribute power : power;
        attribute sourceType : String;
    }

    item def StorageStatus {
        attribute stateOfCharge : Real;
        attribute availablePower : power;
    }

    item def ControlCommand {
        attribute commandAction : ControlAction;
        attribute target : String;
        attribute targetPower : power;
    }

    port def PowerInPort {
        in power : power;
    }

    port def PowerOutPort {
        out power : power;
    }

    port def MeterDataInPort {
        in reading : MeterReading;
    }

    port def MeterDataOutPort {
        out reading : MeterReading;
    }

    port def GenDataInPort {
        in genData : GenerationData;
    }

    port def GenDataOutPort {
        out genData : GenerationData;
    }

    port def StorageDataInPort {
        in status : StorageStatus;
    }

    port def StorageDataOutPort {
        out status : StorageStatus;
    }

    port def CmdInPort {
        in cmd : ControlCommand;
    }

    port def CmdOutPort {
        out cmd : ControlCommand;
    }

    part def PowerGenerator {
        attribute maxCapacity : power;
        port powerOut : PowerOutPort;
        port controlIn : CmdInPort;
        port genStatusOut : GenDataOutPort;
        action generatePower;
    }

    part def SolarFarm :> PowerGenerator {
        doc /* Renewable solar power generation facility. */
        attribute panelArea : area;
    }

    part def WindTurbine :> PowerGenerator {
        doc /* Renewable wind power generation. */
        attribute rotorDiameter : length;
    }

    part def NaturalGasPlant :> PowerGenerator {
        doc /* Conventional baseload power generation. */
        attribute minCapacity : power;
    }

    part def BatteryStorage {
        attribute capacity : energy;
        attribute stateOfCharge : Real = 0.5;
        port powerIn : PowerInPort;
        port powerOut : PowerOutPort;
        port controlIn : CmdInPort;
        port statusOut : StorageDataOutPort;
        action charge;
        action discharge;
    }

    part def TransmissionLine {
        attribute voltageRating : electricPotential;
        port powerIn : PowerInPort;
        port powerOut : PowerOutPort;
    }

    part def Substation {
        attribute inputVoltage : electricPotential;
        attribute outputVoltage : electricPotential;
        port powerIn : PowerInPort;
        port powerOut : PowerOutPort;
    }

    part def PrimarySubstation :> Substation {
        doc /* Steps down high voltage to medium voltage. */
    }

    part def SecondarySubstation :> Substation {
        doc /* Steps down medium voltage to low voltage for distribution. */
    }

    part def SmartMeter {
        port powerIn : PowerInPort;
        port dataOut : MeterDataOutPort;
        action measureDemand {
            out reading : MeterReading;
        }
    }

    part def Consumer {
        attribute priority : PriorityLevel;
        port powerIn : PowerInPort;
        part smartMeter : SmartMeter;
    }

    part def IndustrialConsumer :> Consumer {
        doc /* Critical-priority industrial loads. */
        redefines priority = PriorityLevel::critical;
    }

    part def CommercialConsumer :> Consumer {
        doc /* High-priority commercial loads. */
        redefines priority = PriorityLevel::high;
    }

    part def ResidentialConsumer :> Consumer {
        doc /* Low-priority residential loads. */
        redefines priority = PriorityLevel::low;
    }

    part def GridControlCenter {
        port meterDataIn : MeterDataInPort;
        port genDataIn : GenDataInPort;
        port storageDataIn : StorageDataInPort;
        port controlOut : CmdOutPort;

        attribute totalDemand : power;
        attribute totalSupply : power;

        action optimizeGeneration;
        action dischargeBatteries;
        action chargeBatteries;
        action rampDownGas;
        action shedLoad;
        action emergencyProtocol;

        exhibit state gridManagement {
            state stable {
                entry optimizeGeneration;
            }
            state overloaded {
                entry dischargeBatteries;
                do shedLoad;
            }
            state underloaded {
                entry chargeBatteries;
                do rampDownGas;
            }
            state critical {
                entry emergencyProtocol;
            }

            transition initial then stable;
            transition stable_to_overloaded
                first stable
                if totalDemand > totalSupply
                then overloaded;
            transition stable_to_underloaded
                first stable
                if totalSupply > totalDemand * 1.1
                then underloaded;
            transition stable_to_critical
                first stable
                if totalDemand > totalSupply * 1.2
                then critical;
            transition overloaded_to_stable
                first overloaded
                if totalDemand <= totalSupply
                then stable;
            transition overloaded_to_critical
                first overloaded
                if totalDemand > totalSupply * 1.2
                then critical;
            transition underloaded_to_stable
                first underloaded
                if totalSupply <= totalDemand * 1.1
                then stable;
            transition critical_to_stable
                first critical
                if totalDemand <= totalSupply
                then stable;
        }
    }

    part def SmartGridSystem {
        part solarFarm : SolarFarm {
            :>> maxCapacity = 1000000 [W];
        }
        part windTurbine : WindTurbine {
            :>> maxCapacity = 500000 [W];
        }
        part naturalGasPlant : NaturalGasPlant {
            :>> maxCapacity = 2000000 [W];
            :>> minCapacity = 500000 [W];
        }
        part batteryStorage : BatteryStorage {
            :>> capacity = 5000000 [Wh];
        }
        part transmissionLine : TransmissionLine {
            :>> voltageRating = 110000 [V];
        }
        part primarySubstation : PrimarySubstation {
            :>> inputVoltage = 110000 [V];
            :>> outputVoltage = 33000 [V];
        }
        part secondarySubstation : SecondarySubstation {
            :>> inputVoltage = 33000 [V];
            :>> outputVoltage = 400 [V];
        }
        part industrialConsumer : IndustrialConsumer;
        part commercialConsumer : CommercialConsumer;
        part residentialConsumer : ResidentialConsumer;
        part controlCenter : GridControlCenter;

        connect solarFarm.powerOut to transmissionLine.powerIn;
        connect windTurbine.powerOut to transmissionLine.powerIn;
        connect naturalGasPlant.powerOut to transmissionLine.powerIn;
        connect batteryStorage.powerOut to transmissionLine.powerIn;
        connect transmissionLine.powerOut to primarySubstation.powerIn;
        connect primarySubstation.powerOut to secondarySubstation.powerIn;
        connect secondarySubstation.powerOut to industrialConsumer.powerIn;
        connect secondarySubstation.powerOut to commercialConsumer.powerIn;
        connect secondarySubstation.powerOut to residentialConsumer.powerIn;
        connect primarySubstation.powerOut to batteryStorage.powerIn;

        connect industrialConsumer.smartMeter.dataOut to controlCenter.meterDataIn;
        connect commercialConsumer.smartMeter.dataOut to controlCenter.meterDataIn;
        connect residentialConsumer.smartMeter.dataOut to controlCenter.meterDataIn;
        connect solarFarm.genStatusOut to controlCenter.genDataIn;
        connect windTurbine.genStatusOut to controlCenter.genDataIn;
        connect naturalGasPlant.genStatusOut to controlCenter.genDataIn;
        connect batteryStorage.statusOut to controlCenter.storageDataIn;
        connect controlCenter.controlOut to solarFarm.controlIn;
        connect controlCenter.controlOut to windTurbine.controlIn;
        connect controlCenter.controlOut to naturalGasPlant.controlIn;
        connect controlCenter.controlOut to batteryStorage.controlIn;

        flow powerFlowSolar of power
            from solarFarm.powerOut.power to transmissionLine.powerIn.power;
        flow powerFlowWind of power
            from windTurbine.powerOut.power to transmissionLine.powerIn.power;
        flow powerFlowGas of power
            from naturalGasPlant.powerOut.power to transmissionLine.powerIn.power;
        flow powerFlowBattery of power
            from batteryStorage.powerOut.power to transmissionLine.powerIn.power;
        flow powerFlowTrans of power
            from transmissionLine.powerOut.power to primarySubstation.powerIn.power;
        flow powerFlowPrimary of power
            from primarySubstation.powerOut.power to secondarySubstation.powerIn.power;
        flow powerFlowCharge of power
            from primarySubstation.powerOut.power to batteryStorage.powerIn.power;
        flow powerFlowInd of power
            from secondarySubstation.powerOut.power to industrialConsumer.powerIn.power;
        flow powerFlowCom of power
            from secondarySubstation.powerOut.power to commercialConsumer.powerIn.power;
        flow powerFlowRes of power
            from secondarySubstation.powerOut.power to residentialConsumer.powerIn.power;

        flow meterFlowInd of MeterReading
            from industrialConsumer.smartMeter.dataOut.reading to controlCenter.meterDataIn.reading;
        flow meterFlowCom of MeterReading
            from commercialConsumer.smartMeter.dataOut.reading to controlCenter.meterDataIn.reading;
        flow meterFlowRes of MeterReading
            from residentialConsumer.smartMeter.dataOut.reading to controlCenter.meterDataIn.reading;
        flow genFlowSolar of GenerationData
            from solarFarm.genStatusOut.genData to controlCenter.genDataIn.genData;
        flow genFlowWind of GenerationData
            from windTurbine.genStatusOut.genData to controlCenter.genDataIn.genData;
        flow genFlowGas of GenerationData
            from naturalGasPlant.genStatusOut.genData to controlCenter.genDataIn.genData;
        flow storageFlow of StorageStatus
            from batteryStorage.statusOut.status to controlCenter.storageDataIn.status;
        flow cmdFlow1 of ControlCommand
            from controlCenter.controlOut.cmd to solarFarm.controlIn.cmd;
        flow cmdFlow2 of ControlCommand
            from controlCenter.controlOut.cmd to windTurbine.controlIn.cmd;
        flow cmdFlow3 of ControlCommand
            from controlCenter.controlOut.cmd to naturalGasPlant.controlIn.cmd;
        flow cmdFlow4 of ControlCommand
            from controlCenter.controlOut.cmd to batteryStorage.controlIn.cmd;
    }

    part smartGrid : SmartGridSystem;

    requirement def GridStabilityRequirement {
        doc /* The Smart Grid shall automatically balance generation and consumption to avoid overloaded or underloaded states. */
    }

    requirement def RenewablePriorityRequirement {
        doc /* In the stable state, the control center shall maximize solar and wind generation and minimize natural gas output. */
    }

    requirement def LoadSheddingRequirement {
        doc /* When overloaded, the control center shall draw from battery storage and shed low-priority residential loads before affecting commercial or industrial consumers. */
    }

    requirement def BatteryManagementRequirement {
        doc /* The battery shall charge when generation exceeds demand and discharge when demand exceeds generation. */
    }

    requirement def EmergencyResponseRequirement {
        doc /* When demand exceeds 120 percent of supply, the control center shall enter a critical state and execute emergency protocols to prevent total blackout. */
    }

    requirement gridStabilityReq : GridStabilityRequirement;
    requirement renewablePriorityReq : RenewablePriorityRequirement;
    requirement loadSheddingReq : LoadSheddingRequirement;
    requirement batteryMgmtReq : BatteryManagementRequirement;
    requirement emergencyRespReq : EmergencyResponseRequirement;

    satisfy gridStabilityReq by smartGrid.controlCenter;
    satisfy renewablePriorityReq by smartGrid.controlCenter;
    satisfy loadSheddingReq by smartGrid.controlCenter;
    satisfy batteryMgmtReq by smartGrid.batteryStorage;
    satisfy emergencyRespReq by smartGrid.controlCenter;
}
