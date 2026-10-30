-- Only the APIs needed by the Hub. No network, player input, or live game.
local function signal()
    local result={connections={}}
    function result:Connect(callback)
        local connection={Connected=true,callback=callback}
        function connection:Disconnect() self.Connected=false end
        table.insert(self.connections,connection)
        return connection
    end
    function result:Fire(...)
        for _,connection in ipairs(table.clone(self.connections)) do
            if connection.Connected then connection.callback(...) end
        end
    end
    return result
end
local vector={}
local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z or 0},vector) end
vector.__add=function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vector.__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vector.__mul=function(a,b) return vec(a.X*b,a.Y*b,a.Z*b) end
vector.__index=function(a,k)
    if k=='Magnitude' then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end
end
local Vector2={new=vec}
local Vector3={new=vec}
local UDim={new=function(s,o) return {Scale=s,Offset=o} end}
local UDim2={}
function UDim2.new(xs,xo,ys,yo) return {X=UDim.new(xs,xo),Y=UDim.new(ys,yo)} end
function UDim2.fromOffset(x,y) return UDim2.new(0,x,0,y) end
function UDim2.fromScale(x,y) return UDim2.new(x,0,y,0) end
local Color3={fromRGB=function(r,g,b) return r*65536+g*256+b end}
local Enum=setmetatable({}, {__index=function(t,key)
    local group=setmetatable({}, {__index=function(g,k)
        local value={Name=k,Value=k=='Camera' and 200 or 0}
        rawset(g,k,value)
        return value
    end})
    rawset(t,key,group)
    return group
end})
local objects={}
local methods={}
local objectMeta={}
local function totalScale(object)
    local factor=1
    while object do
        for _,child in ipairs(object._children) do
            if child.ClassName=='UIScale' then factor*=child.Scale end
        end
        object=object.Parent
    end
    return factor
end
objectMeta.__index=function(self,key)
    if methods[key] then return methods[key] end
    if key=='AbsoluteSize' then
        if self.ClassName=='ScreenGui' or self.ClassName=='PlayerGui' then return objects.viewport end
        local parent=self.Parent and self.Parent.AbsoluteSize or objects.viewport
        local size=self.Size or UDim2.fromOffset(0,0)
        local factor=totalScale(self)
        return vec(parent.X*size.X.Scale+size.X.Offset*factor,parent.Y*size.Y.Scale+size.Y.Offset*factor)
    end
    if key=='AbsolutePosition' then
        local parent=self.Parent and self.Parent.AbsolutePosition or vec(0,0)
        local size=self.Parent and self.Parent.AbsoluteSize or objects.viewport
        local pos=self.Position or UDim2.fromOffset(0,0)
        local ownSize=self.AbsoluteSize
        local anchor=self.AnchorPoint or vec(0,0)
        return vec(parent.X+size.X*pos.X.Scale+pos.X.Offset*totalScale(self)-ownSize.X*anchor.X,
            parent.Y+size.Y*pos.Y.Scale+pos.Y.Offset*totalScale(self)-ownSize.Y*anchor.Y)
    end
    return self._props[key]
end
objectMeta.__newindex=function(self,key,value)
    if key=='Parent' then
        local old=self._props.Parent
        if old then
            local index=table.find(old._children,self)
            if index then table.remove(old._children,index) end
        end
        if value then table.insert(value._children,self) end
    end
    self._props[key]=value
end
local Instance={}
function Instance.new(class)
    local object=setmetatable({_props={ClassName=class,Name=class},_children={},_signals={}},objectMeta)
    for _,key in ipairs({'InputBegan','InputChanged','InputEnded','Activated'}) do object[key]=signal() end
    object.Visible=true
    object.Size=UDim2.fromOffset(0,0)
    object.Position=UDim2.fromOffset(0,0)
    table.insert(objects,object)
    return object
end
function methods:GetChildren() return table.clone(self._children) end
function methods:FindFirstChild(name)
    for _,child in ipairs(self._children) do if child.Name==name then return child end end
end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name),name) end
function methods:FindFirstChildOfClass(class)
    for _,child in ipairs(self._children) do if child.ClassName==class then return child end end
end
function methods:IsA(class)
    return self.ClassName==class or (class=='GuiObject' and
        table.find({'Frame','TextButton','TextLabel','ScrollingFrame'},self.ClassName)~=nil)
end
function methods:GetPropertyChangedSignal(key)
    if not self._signals[key] then self._signals[key]=signal() end
    return self._signals[key]
end
function methods:GetAttribute(key) return self._props[key..'Attribute'] end
function methods:GetFullName() return self.Name end
function methods:IsDescendantOf(ancestor)
    local parent=self.Parent
    while parent do if parent==ancestor then return true end; parent=parent.Parent end
    return false
end
function methods:Destroy()
    for _,child in ipairs(self:GetChildren()) do child:Destroy() end
    for _,value in pairs(self._props) do
        if type(value)=='table' and value.connections then
            for _,connection in ipairs(value.connections) do connection:Disconnect() end
        end
    end
    self.Parent=nil
    self.Destroyed=true
end
local RaycastParams={new=function() return {} end}
local task={queue={}}
function task.spawn(callback) table.insert(task.queue,callback) end
function task.defer(callback) table.insert(task.queue,callback) end
function task.wait() coroutine.yield() end
local environment={}
local function getgenv() return environment end
local lp=Instance.new('Player')
lp.Name='Local'; lp.UserId=1; lp.Neutral=false; lp.Team='Blue'; lp.TeamColor='Blue'
function lp:IsFriendsWithAsync() return false end
local playerGui=Instance.new('PlayerGui'); playerGui.Name='PlayerGui'; playerGui.Parent=lp
local players={LocalPlayer=lp,PlayerAdded=signal(),PlayerRemoving=signal(),list={lp}}
function players:GetPlayers() return table.clone(self.list) end
function players:GetPlayerFromCharacter(character)
    for _,player in ipairs(self.list) do if player.Character==character then return player end end
end
local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
function input:GetFocusedTextBox() return nil end
local runService={bindings={}}
function runService:BindToRenderStep(key,_,callback) self.bindings[key]=callback end
function runService:UnbindFromRenderStep(key) self.bindings[key]=nil end
objects.viewport=vec(1000,800)
local camera=Instance.new('Camera'); camera.ViewportSize=objects.viewport
camera.CFrame={Position=vec(0,0,0)}
function camera:WorldToViewportPoint(position) return position,true end
local workspace=Instance.new('Workspace'); workspace.CurrentCamera=camera
function workspace:Raycast() return nil end
local game={}
function game:GetService(name)
    return ({Players=players,RunService=runService,UserInputService=input,Workspace=workspace})[name]
end
local function find(parent,key,value)
    for _,child in ipairs(parent:GetChildren()) do
        if child[key]==value then return child end
        local nested=find(child,key,value)
        if nested then return nested end
    end
end
local function named(name) return assert(find(playerGui,'Name',name),'Missing '..name) end
local function byText(text) return assert(find(playerGui,'Text',text),'Missing text '..text) end
local function control(title)
    local caption=byText(title)
    return assert(caption.Parent:FindFirstChildOfClass('TextButton'),'No control: '..title)
end
local function pointer(kind,x,y) return {UserInputType=Enum.UserInputType[kind],Position=vec(x,y)} end
local function press(object) object.Activated:Fire() end
local function near(a,b) assert(math.abs(a-b)<0.001,tostring(a)..' != '..tostring(b)) end
local passed=0
local function test(name,callback)
    callback()
    passed+=1
    print('PASS '..name)
end
