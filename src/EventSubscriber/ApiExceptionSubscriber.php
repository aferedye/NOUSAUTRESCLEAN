<?php
namespace App\EventSubscriber;

use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpKernel\Event\ExceptionEvent;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Symfony\Component\HttpKernel\KernelEvents;

class ApiExceptionSubscriber implements EventSubscriberInterface
{
    public static function getSubscribedEvents(): array
    {
        return [ KernelEvents::EXCEPTION => ['onException', 0] ];
    }

    public function onException(ExceptionEvent $event): void
    {
        $request = $event->getRequest();
        if (strpos($request->getPathInfo(), '/api/') !== 0) return;

        $e = $event->getThrowable();
        $status = $e instanceof HttpExceptionInterface ? $e->getStatusCode() : 500;
        $isDev = ($_ENV['APP_ENV'] ?? 'prod') === 'dev';

        $payload = [
            'status' => $status,
            'error' => (new \ReflectionClass($e))->getShortName(),
            'message' => $e instanceof HttpExceptionInterface ? $e->getMessage() : ($isDev ? $e->getMessage() : 'Server error'),
            'path' => $request->getPathInfo(),
            'time' => (new \DateTimeImmutable())->format(\DateTimeInterface::ATOM),
        ];
        if ($isDev) {
            $prev = $e->getPrevious();
            if ($prev) $payload['previous'] = ['error' => (new \ReflectionClass($prev))->getShortName(), 'message' => $prev->getMessage()];
            $payload['trace'] = $e->getTraceAsString();
        }
        $event->setResponse(new JsonResponse($payload, $status));
    }
}