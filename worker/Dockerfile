FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build

WORKDIR /source

COPY *.csproj .
RUN dotnet restore

COPY . .
RUN dotnet publish -c Release -o /app

FROM mcr.microsoft.com/dotnet/runtime:7.0-alpine

WORKDIR /app

# Copy built application
COPY --from=build /app .

# Create non-root user and change ownership
RUN adduser -D -u 1000 appuser && \
    chown -R appuser:appuser /app

USER appuser

ENV DOTNET_TieredCompilation=false \
    DOTNET_TieredCompilationQuickJit=false \
    DOTNET_TieredCompilationQuickJitForLoops=false

CMD ["dotnet", "Worker.dll"]