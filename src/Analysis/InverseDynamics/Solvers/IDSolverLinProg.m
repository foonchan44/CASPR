% Basic Inverse Dynamics solver for problems in the Linear Program form
% This is a well-studied form of inverse dynamics solver for CDPRs.
%
% Author        : Darwin LAU
% Created       : 2015
% Description   : Only a linear objective function and linear 
% constraints can be used with this solver. There are multiple types of LP
% solver implementations that can be used with this solver.
classdef IDSolverLinProg < IDSolverFunction
    
    properties (SetAccess = private)
        lp_solver_type
        objective
        constraints = {}
        options
    end
    methods
        function q = IDSolverLinProg(objective, lp_solver_type)
            q.objective = objective;
            q.lp_solver_type = lp_solver_type;
            q.options = [];
        end
        
        function [Q_opt, id_exit_type] = resolveFunction(obj, dynamics)            
            % Form the linear EoM constraint
            % M\ddot{q} + C + G + F_{ext} = -J^T f (constraint)
            [A_eq, b_eq] = IDSolverFunction.GetEoMConstraints(dynamics);  
            % Form the lower and upper bound force constraints
            fmin = dynamics.cableDynamics.forcesMin;
            fmax = dynamics.cableDynamics.forcesMax;
            % Get objective function
            obj.objective.updateObjective(dynamics);
                        
            A_ineq = [];
            b_ineq = [];
            for i = 1:length(obj.constraints)
                obj.constraints{i}.updateConstraint(dynamics);
                A_ineq = [A_ineq; obj.constraints{i}.A];
                b_ineq = [b_ineq; obj.constraints{i}.b];                
            end
            
            switch (obj.lp_solver_type)
                case ID_LP_SolverType.MATLAB
                    if(isempty(obj.options))
                        obj.options = optimoptions('linprog', 'Display', 'off', 'Algorithm', 'interior-point');
                    end
                    [dynamics.cableForces, id_exit_type] = id_lp_matlab(obj.objective.b, A_ineq, A_ineq, A_eq, b_eq, fmin, fmax, obj.f_previous,obj.options);
                case ID_LP_SolverType.OPTITOOLBOX_CLP
                    [dynamics.cableForces, id_exit_type] = id_lp_optitoolbox_clp(obj.objective.b, A_ineq, A_ineq, A_eq, b_eq, fmin, fmax, obj.f_previous);
                otherwise
                    error('ID_LP_SolverType type is not defined');
            end
            
            if (id_exit_type ~= IDSolverExitType.NO_ERROR)
                dynamics.cableForces = dynamics.cableDynamics.forcesInvalid;
                Q_opt = inf;
                %id_exit_type = IDFunction.DisplayOptiToolboxError(exitflag);
            else
                Q_opt = obj.objective.evaluateFunction(dynamics.cableForces);
            end            
            
            obj.f_previous = dynamics.cableForces;
        end
        
        function addConstraint(obj, linConstraint)
            obj.constraints{length(obj.constraints)+1} = linConstraint;
        end
    end
end

