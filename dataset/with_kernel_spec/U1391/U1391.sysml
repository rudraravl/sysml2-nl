package 'Vehicle Manufacturing Plant' {
    private import ScalarValues::*;
    private import SI::kg;

    item def SteelSheet {
        attribute thickness : Real;
        attribute mass : kg;
    }

    item def BodyPanel {
        attribute panelType : String;
        attribute mass : kg;
    }

    item def Chassis {
        attribute frameNumber : String;
        attribute mass : kg;
    }

    item def PaintedChassis :> Chassis {
        attribute color : String;
    }

    part def Engine {
        attribute displacement : Real;
        attribute power : Real;
    }

    part def Transmission {
        attribute gearCount : Integer;
    }

    part def Powertrain {
        part engine : Engine;
        part transmission : Transmission;
    }

    part def FunctionalVehicle {
        attribute vin : String;
        part powertrain : Powertrain;
        part chassis : PaintedChassis;
    }

    part def TestedVehicle :> FunctionalVehicle {
        attribute qualityScore : Real;
        attribute isApproved : Boolean;
    }

    part def Press {
        attribute name : String;
        attribute maxForce : Integer;
    }

    part def RoboticWelder {
        attribute name : String;
        attribute armCount : Integer;
    }

    part def PaintBooth {
        attribute name : String;
        attribute temperature : Real;
        attribute humidity : Real;
    }

    part def AssemblyRobot {
        attribute name : String;
        attribute maxTorque : Real;
    }

    part def TestRig {
        attribute name : String;
        attribute testDuration : Real;
    }

    port def SteelPort {
        out item steel : SteelSheet;
    }

    port def PanelPort {
        out item panel : BodyPanel;
    }

    port def ChassisPort {
        out item chassis : Chassis;
    }

    port def PaintedChassisPort {
        out item paintedChassis : PaintedChassis;
    }

    port def PowertrainPort {
        out item powertrain : Powertrain;
    }

    port def VehiclePort {
        out item vehicle : FunctionalVehicle;
    }

    port def TestedVehiclePort {
        out item testedVehicle : TestedVehicle;
    }

    requirement def ProductionTarget {
        attribute vehiclesPerDay : Integer;
        attribute minQualityStandard : Real;
        attribute operationalEfficiency : Real;
    }

    requirement def QualityStandard {
        attribute qualityThreshold : Real;
    }

    requirement plantProductionTarget : ProductionTarget {
        :>> vehiclesPerDay = 500;
        :>> minQualityStandard = 95.0;
        :>> operationalEfficiency = 0.90;
    }

    requirement plantQualityStandard : QualityStandard {
        :>> qualityThreshold = 90.0;
    }

    state def PlantOperationalState {
        state offline;
        state operational;
        state maintenance;

        transition startProduction first offline -> operational;
        transition beginMaintenance operational -> maintenance;
        transition resumeProduction maintenance -> operational;
        transition stopProduction operational -> offline;
    }

    action def StampPanels {
        in item steel : SteelSheet;
        out item panel : BodyPanel;
    }

    action def WeldChassis {
        in item panels : BodyPanel;
        out item chassis : Chassis;
    }

    action def PaintChassis {
        in item chassis : Chassis;
        out item paintedChassis : PaintedChassis;
    }

    action def AssembleVehicle {
        in item paintedChassis : PaintedChassis;
        in item powertrain : Powertrain;
        out item vehicle : FunctionalVehicle;
    }

    action def TestVehicle {
        in item vehicle : FunctionalVehicle;
        out item testedVehicle : TestedVehicle;
    }

    action def AssemblyLineProcess {
        action stamp {
            in item steel : SteelSheet;
            out item panel : BodyPanel;
        }
        action weld {
            in item panels : BodyPanel;
            out item chassis : Chassis;
        }
        action paint {
            in item chassis : Chassis;
            out item paintedChassis : PaintedChassis;
        }
        action assemble {
            in item paintedChassis : PaintedChassis;
            in item powertrain : Powertrain;
            out item vehicle : FunctionalVehicle;
        }
        action test {
            in item vehicle : FunctionalVehicle;
            out item testedVehicle : TestedVehicle;
        }

        flow stamp.panel to weld.panels;
        flow weld.chassis to paint.chassis;
        flow paint.paintedChassis to assemble.paintedChassis;
        flow assemble.vehicle to test.vehicle;
    }

    part def StampingDepartment {
        attribute pressCount : Integer;
        part presses : Press[*];

        in port steelIn : ~SteelPort;
        out port panelOut : PanelPort;

        perform StampPanels;
    }

    part def WeldingDepartment {
        attribute welderCount : Integer;
        part welders : RoboticWelder[*];

        in port panelIn : ~PanelPort;
        out port chassisOut : ChassisPort;

        perform WeldChassis;
    }

    part def PaintingDepartment {
        attribute boothCount : Integer;
        part booths : PaintBooth[*];

        in port chassisIn : ~ChassisPort;
        out port paintedChassisOut : PaintedChassisPort;

        perform PaintChassis;
    }

    part def FinalAssemblyDepartment {
        attribute stationCount : Integer;
        part robots : AssemblyRobot[*];

        in port paintedChassisIn : ~PaintedChassisPort;
        in port powertrainIn : ~PowertrainPort;
        out port vehicleOut : VehiclePort;

        perform AssembleVehicle;
    }

    part def QualityTestingFacility {
        attribute rigCount : Integer;
        part rigs : TestRig[*];

        in port vehicleIn : ~VehiclePort;
        out port testedVehicleOut : TestedVehiclePort;

        perform TestVehicle;
    }

    part plant {
        exhibit state operationalState : PlantOperationalState;
        satisfy plantProductionTarget;
        satisfy plantQualityStandard;

        in port rawSteelIn : ~SteelPort;
        in port powertrainSupplyIn : ~PowertrainPort;
        out port approvedVehicleOut : TestedVehiclePort;

        part stamping : StampingDepartment {
            :>> pressCount = 8;
        }
        part welding : WeldingDepartment {
            :>> welderCount = 15;
        }
        part painting : PaintingDepartment {
            :>> boothCount = 4;
        }
        part assembly : FinalAssemblyDepartment {
            :>> stationCount = 12;
        }
        part testing : QualityTestingFacility {
            :>> rigCount = 6;
        }

        bind rawSteelIn = stamping.steelIn;
        bind powertrainSupplyIn = assembly.powertrainIn;
        bind approvedVehicleOut = testing.testedVehicleOut;

        connect stamping.panelOut to welding.panelIn;
        connect welding.chassisOut to painting.chassisIn;
        connect painting.paintedChassisOut to assembly.paintedChassisIn;
        connect assembly.vehicleOut to testing.vehicleIn;

        perform AssemblyLineProcess;
    }
}
