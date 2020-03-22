% The types of hosts and various properties associated with them like memory, cpu, cost, etc.
int: hostTypes = 10;
array[1..hostTypes] of int: hostCpu = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
array[1..hostTypes] of int: hostMem = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
array[1..hostTypes] of int: hostCost = [2, 4, 6, 8, 10, 12, 14, 16, 18, 20];

% The tasks and their associated properties like memory and cpu requirements.
int: numTasks = 10;
array[1..numTasks] of int: taskCpu = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
array[1..numTasks] of int: taskMem = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

% These are the mappings for what type of host do we assign to each task.
array[1..numTasks] of var 0..hostTypes: taskHostAssignment;
array[1..hostTypes] of var set of 1..numTasks: hostTaskAssignment;

% Some global constraints to make certain constraints easier to express.
include "int_set_channel.mzn";
include "among.mzn";

% This means that these two mappings are "inverses" of each other.
% This is useful because once tasks are assigned to a host we need
% to iterate over them and compute certain totals so we know how
% many hosts of each type to provision.
constraint int_set_channel(taskHostAssignment, hostTaskAssignment);

% Tasks assigned to the host must satisfy memory and cpu limits. If
% a task requires 10 memory units then it can't be assigned to a host
% that has only 5 memory units. Similarly for any other constraint like
% CPU.
constraint forall(h in 1..hostTypes)(
  forall(t in hostTaskAssignment[h])(
    taskCpu[t] <= hostCpu[h] /\ taskMem[t] <= hostMem[h]
  )
);

% Now we can figure out how many hosts of each type we need based
% on how many tasks we have assigned to the host. Number of hosts
% is the number of hosts required to not overflow the total memory
% and cpu limits of the tasks assigned to the host type. Basically,
% we are doing a greedy bin packing computation where the bins are
% the limits of the host. So we need X bins to fulfill the total
% task requirements where the bins are the hosts.
array[1..hostTypes] of var int: requiredHostCounts;
constraint forall(h in 1..hostTypes)(
  let {
    var int: perHostCpuTotal = sum(
      t in hostTaskAssignment[h])(taskCpu[t]);
    var int: perHostMemTotal = sum(
      t in hostTaskAssignment[h])(taskMem[t]);
    var int: cpuRemainder =
      if perHostCpuTotal mod hostCpu[h] > 0 then
        1 else 0 endif;
    var int: memRemainder =
      if perHostMemTotal div hostMem[h] > 0 then
        1 else 0 endif;
  } in
  requiredHostCounts[h] = max(
    perHostCpuTotal div hostCpu[h] + cpuRemainder,
    perHostMemTotal div hostMem[h] + memRemainder)
);

% Now we can compute the costs associated with how many hosts we need by
% multiplying the host counts with per unit costs.
array[1..hostTypes] of var int: requiredHostCosts;
constraint forall(h in 1..hostTypes)(
  requiredHostCosts[h] = requiredHostCounts[h] * hostCost[h]
);

% The total cost is then just the sum of the cost for each host type.
var int: totalCost = sum(h in 1..hostTypes)(requiredHostCosts[h]);

% We want to minimize the total cost so we finish the tasks
% as cheaply as possible.
solve minimize totalCost;

% Cost and associated assignments for each task along with the host counts.
output ["Cost: \(totalCost).\n"] ++
  ["Assignments: \(taskHostAssignment).\n"] ++
  ["Counts: \(requiredHostCounts)."];